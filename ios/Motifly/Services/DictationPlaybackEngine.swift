import AVFoundation
import Foundation

enum DictationPlaybackSource: String, Codable, CaseIterable, Identifiable {
    case tts
    case mine

    var id: String { rawValue }

    var title: String {
        switch self {
        case .tts: return "TTS"
        case .mine: return "Mine"
        }
    }
}

struct DictationPlaybackPass: Codable, Equatable, Identifiable {
    var id: UUID = UUID()
    var source: DictationPlaybackSource
    /// Delay after this play pass, before next pass starts.
    var delayAfterSeconds: Double
}

struct DictationTimingProfile: Codable, Equatable {
    var mode: String
    var passes: [DictationPlaybackPass]

    static var manualDefault: DictationTimingProfile {
        DictationTimingProfile(
            mode: "manual",
            passes: [DictationPlaybackPass(source: .tts, delayAfterSeconds: 0)]
        )
    }

    static var autoDefault: DictationTimingProfile {
        DictationTimingProfile(
            mode: "auto",
            passes: [
                DictationPlaybackPass(source: .tts, delayAfterSeconds: 2),
                DictationPlaybackPass(source: .tts, delayAfterSeconds: 2),
                DictationPlaybackPass(source: .tts, delayAfterSeconds: 4),
            ]
        )
    }
}

struct DictationPlaybackTraceEvent: Codable {
    var source: String
    var startedAt: Date
    var durationMs: Int
    var fallbackReason: String?
}

@MainActor
final class DictationPlaybackEngine: NSObject, ObservableObject {
    private var speechSynth = AVSpeechSynthesizer()
    private var ttsContinuation: CheckedContinuation<Void, Never>?

    override init() {
        super.init()
        speechSynth.delegate = self
    }

    func playProfile(
        word: VocabularyEntry,
        profile: DictationTimingProfile,
        onTrace: (DictationPlaybackTraceEvent) -> Void
    ) async {
        guard !profile.passes.isEmpty else { return }
        for (index, pass) in profile.passes.enumerated() {
            let event = await playOnePass(word: word, pass: pass)
            onTrace(event)
            if index < profile.passes.count - 1 {
                let ns = UInt64(max(0, pass.delayAfterSeconds) * 1_000_000_000)
                if ns > 0 {
                    try? await Task.sleep(nanoseconds: ns)
                }
            }
        }
    }

    private func playOnePass(word: VocabularyEntry, pass: DictationPlaybackPass) async -> DictationPlaybackTraceEvent {
        let startedAt = Date()
        var fallbackReason: String?
        let actualSource: DictationPlaybackSource
        let durationMs: Int

        switch pass.source {
        case .tts:
            actualSource = .tts
            durationMs = await speakTTS(word.frenchLemma)
        case .mine:
            if let mineMs = await playMineIfAvailable(seedNumber: word.seedNumber) {
                actualSource = .mine
                durationMs = mineMs
            } else {
                // Fallback keeps auto flow stable when no recording exists yet.
                fallbackReason = "mine_unavailable_fallback_tts"
                actualSource = .tts
                durationMs = await speakTTS(word.frenchLemma)
            }
        }

        return DictationPlaybackTraceEvent(
            source: actualSource.rawValue,
            startedAt: startedAt,
            durationMs: durationMs,
            fallbackReason: fallbackReason
        )
    }

    private func speakTTS(_ text: String) async -> Int {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return 0 }
        if speechSynth.isSpeaking {
            speechSynth.stopSpeaking(at: .immediate)
        }
        prepareAudioSessionForPlayback()
        let start = Date()
        let utterance = AVSpeechUtterance(string: trimmed)
        utterance.voice = Self.preferredFrenchVoice()
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.92
        speechSynth.speak(utterance)
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            ttsContinuation = cont
        }
        return max(0, Int(Date().timeIntervalSince(start) * 1000))
    }

    private func playMineIfAvailable(seedNumber: Int) async -> Int? {
        guard let url = try? MinePronunciationStorage.fileURL(seedNumber: seedNumber),
              FileManager.default.fileExists(atPath: url.path),
              let player = try? AVAudioPlayer(contentsOf: url),
              player.duration > 0 else { return nil }
        prepareAudioSessionForPlayback()
        let durationMs = max(0, Int(player.duration * 1000))
        player.prepareToPlay()
        player.play()
        try? await Task.sleep(nanoseconds: UInt64(player.duration * 1_000_000_000))
        return durationMs
    }

    private func prepareAudioSessionForPlayback() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try session.setActive(true, options: [])
        } catch {
            try? session.setActive(true, options: [])
        }
    }

    private static func preferredFrenchVoice() -> AVSpeechSynthesisVoice? {
        if let frFR = AVSpeechSynthesisVoice(language: "fr-FR") {
            return frFR
        }
        return AVSpeechSynthesisVoice.speechVoices().first { $0.language.hasPrefix("fr") }
    }
}

extension DictationPlaybackEngine: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            ttsContinuation?.resume()
            ttsContinuation = nil
        }
    }

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didCancel utterance: AVSpeechUtterance
    ) {
        Task { @MainActor in
            ttsContinuation?.resume()
            ttsContinuation = nil
        }
    }
}
