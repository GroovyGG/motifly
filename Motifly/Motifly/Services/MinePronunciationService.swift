import AVFoundation
import Combine
import Foundation

/// File paths and helpers for user-recorded pronunciations ("Mine") per vocabulary seed number.
enum MinePronunciationStorage {
    private static let subdir = "mine_recordings"

    static func directoryURL() throws -> URL {
        let appSupport = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let dir = appSupport.appendingPathComponent("Motifly", isDirectory: true).appendingPathComponent(subdir, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func fileURL(seedNumber: Int) throws -> URL {
        try directoryURL().appendingPathComponent("\(seedNumber).m4a")
    }

    static func fileExists(seedNumber: Int) -> Bool {
        guard let url = try? fileURL(seedNumber: seedNumber) else { return false }
        return FileManager.default.fileExists(atPath: url.path)
    }

    /// Replaces any existing file for this seed with the finished recording at `tempURL`.
    static func saveMine(seedNumber: Int, from tempURL: URL) throws {
        let dest = try fileURL(seedNumber: seedNumber)
        if FileManager.default.fileExists(atPath: dest.path) {
            try FileManager.default.removeItem(at: dest)
        }
        try FileManager.default.copyItem(at: tempURL, to: dest)
        try? FileManager.default.removeItem(at: tempURL)
    }

    static func deleteMine(seedNumber: Int) throws {
        let url = try fileURL(seedNumber: seedNumber)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }
}

/// Manages mic capture, pending confirmation, and playback for one noun card.
@MainActor
final class MineRecordingCoordinator: NSObject, ObservableObject {
    @Published private(set) var isRecording = false
    @Published private(set) var awaitingSaveConfirmation = false
    @Published private(set) var hasMineRecording = false

    private var seedNumber: Int = 0
    private var recorder: AVAudioRecorder?
    private var tempRecordingURL: URL?
    private var playbackPlayer: AVAudioPlayer?

    func configure(seedNumber: Int) {
        if self.seedNumber != seedNumber {
            cancelPendingWithoutSaving()
            stopPlayback()
        }
        self.seedNumber = seedNumber
        refreshHasMine()
    }

    func refreshHasMine() {
        hasMineRecording = MinePronunciationStorage.fileExists(seedNumber: seedNumber)
    }

    /// Stop playback/recording and discard pending temp when leaving the card.
    func tearDownOnLeave() {
        stopPlayback()
        if isRecording {
            recorder?.stop()
            recorder = nil
            isRecording = false
        }
        if let temp = tempRecordingURL {
            try? FileManager.default.removeItem(at: temp)
            tempRecordingURL = nil
        }
        awaitingSaveConfirmation = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    /// Request mic access and toggle record/stop.
    func toggleRecording() async {
        if isRecording {
            stopRecordingCapture()
            return
        }

        discardPendingRecording()

        let granted = await Self.requestMicrophonePermission()
        guard granted else { return }

        do {
            try configureAudioSessionForRecording()
            let temp = FileManager.default.temporaryDirectory.appendingPathComponent("mine_\(UUID().uuidString).m4a")
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44_100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
            ]
            let r = try AVAudioRecorder(url: temp, settings: settings)
            r.delegate = self
            guard r.record() else { return }
            recorder = r
            tempRecordingURL = temp
            isRecording = true
            awaitingSaveConfirmation = false
        } catch {
            print("MineRecordingCoordinator start error: \(error)")
        }
    }

    func confirmSaveMine() {
        guard let temp = tempRecordingURL else {
            awaitingSaveConfirmation = false
            return
        }
        do {
            try MinePronunciationStorage.saveMine(seedNumber: seedNumber, from: temp)
            tempRecordingURL = nil
            awaitingSaveConfirmation = false
            refreshHasMine()
        } catch {
            print("MineRecordingCoordinator save error: \(error)")
        }
    }

    func discardPendingRecording() {
        if let temp = tempRecordingURL {
            try? FileManager.default.removeItem(at: temp)
            tempRecordingURL = nil
        }
        awaitingSaveConfirmation = false
    }

    private func cancelPendingWithoutSaving() {
        if isRecording {
            recorder?.stop()
            recorder = nil
            isRecording = false
        }
        if let temp = tempRecordingURL {
            try? FileManager.default.removeItem(at: temp)
            tempRecordingURL = nil
        }
        awaitingSaveConfirmation = false
    }

    private func stopRecordingCapture() {
        recorder?.stop()
        recorder = nil
        isRecording = false
        awaitingSaveConfirmation = tempRecordingURL != nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    func playMine() {
        guard hasMineRecording else { return }
        stopPlayback()
        do {
            try configureAudioSessionForPlayback()
            let url = try MinePronunciationStorage.fileURL(seedNumber: seedNumber)
            playbackPlayer = try AVAudioPlayer(contentsOf: url)
            playbackPlayer?.prepareToPlay()
            playbackPlayer?.play()
        } catch {
            print("MineRecordingCoordinator play error: \(error)")
        }
    }

    /// Preview the current take (temp file) before Save or Discard.
    func playPendingRecording() {
        guard awaitingSaveConfirmation,
              let url = tempRecordingURL,
              FileManager.default.fileExists(atPath: url.path) else { return }
        stopPlayback()
        do {
            try configureAudioSessionForPlayback()
            playbackPlayer = try AVAudioPlayer(contentsOf: url)
            playbackPlayer?.prepareToPlay()
            playbackPlayer?.play()
        } catch {
            print("MineRecordingCoordinator play pending error: \(error)")
        }
    }

    func stopPlayback() {
        playbackPlayer?.stop()
        playbackPlayer = nil
    }

    private func configureAudioSessionForRecording() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        try session.setActive(true)
    }

    private func configureAudioSessionForPlayback() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default)
        try session.setActive(true)
    }

    private static func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { cont in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                cont.resume(returning: granted)
            }
        }
    }
}

extension MineRecordingCoordinator: AVAudioRecorderDelegate {
    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        Task { @MainActor in
            self.isRecording = false
            self.recorder = nil
            if let temp = self.tempRecordingURL {
                try? FileManager.default.removeItem(at: temp)
                self.tempRecordingURL = nil
            }
            self.awaitingSaveConfirmation = false
        }
    }
}
