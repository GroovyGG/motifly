import AVFoundation
import SwiftUI

/// French IPA reference with example words and on-device TTS (example word).
struct FrenchPronunciationToolView: View {
    @Environment(\.colorScheme) private var colorScheme

    enum SoundFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case vowels = "Vowels"
        case consonants = "Consonants"
        var id: String { rawValue }
    }

    enum PhonemeCategory: String {
        case oralVowel
        case nasalVowel
        case semiVowel
        case consonant

        var isVowelFamily: Bool {
            switch self {
            case .oralVowel, .nasalVowel, .semiVowel: return true
            case .consonant: return false
            }
        }
    }

    struct Phoneme: Identifiable, Hashable {
        let id: String
        let ipaDisplay: String
        let exampleWord: String
        let category: PhonemeCategory
    }

    @State private var filter: SoundFilter = .all
    @State private var speechSynth = AVSpeechSynthesizer()

    private let oralVowels: [Phoneme] = [
        .init(id: "i", ipaDisplay: "/i/", exampleWord: "lit", category: .oralVowel),
        .init(id: "e", ipaDisplay: "/e/", exampleWord: "été", category: .oralVowel),
        .init(id: "ɛ", ipaDisplay: "/ɛ/", exampleWord: "mère", category: .oralVowel),
        .init(id: "a", ipaDisplay: "/a/", exampleWord: "chat", category: .oralVowel),
        .init(id: "y", ipaDisplay: "/y/", exampleWord: "tu", category: .oralVowel),
        .init(id: "ø", ipaDisplay: "/ø/", exampleWord: "peu", category: .oralVowel),
        .init(id: "œ", ipaDisplay: "/œ/", exampleWord: "sœur", category: .oralVowel),
        .init(id: "u", ipaDisplay: "/u/", exampleWord: "doux", category: .oralVowel),
        .init(id: "o", ipaDisplay: "/o/", exampleWord: "eau", category: .oralVowel),
        .init(id: "ɔ", ipaDisplay: "/ɔ/", exampleWord: "porte", category: .oralVowel),
        .init(id: "ə", ipaDisplay: "/ə/", exampleWord: "le", category: .oralVowel)
    ]

    private let nasalVowels: [Phoneme] = [
        .init(id: "ɑ̃", ipaDisplay: "/ɑ̃/", exampleWord: "sans", category: .nasalVowel),
        .init(id: "ɛ̃", ipaDisplay: "/ɛ̃/", exampleWord: "pain", category: .nasalVowel),
        .init(id: "ɔ̃", ipaDisplay: "/ɔ̃/", exampleWord: "nom", category: .nasalVowel),
        .init(id: "œ̃", ipaDisplay: "/œ̃/", exampleWord: "parfum", category: .nasalVowel)
    ]

    private let semiVowels: [Phoneme] = [
        .init(id: "j", ipaDisplay: "/j/", exampleWord: "fille", category: .semiVowel),
        .init(id: "ɥ", ipaDisplay: "/ɥ/", exampleWord: "huit", category: .semiVowel),
        .init(id: "w", ipaDisplay: "/w/", exampleWord: "oui", category: .semiVowel)
    ]

    private let consonants: [Phoneme] = [
        .init(id: "p", ipaDisplay: "/p/", exampleWord: "papa", category: .consonant),
        .init(id: "b", ipaDisplay: "/b/", exampleWord: "bon", category: .consonant),
        .init(id: "t", ipaDisplay: "/t/", exampleWord: "tout", category: .consonant),
        .init(id: "d", ipaDisplay: "/d/", exampleWord: "deux", category: .consonant),
        .init(id: "k", ipaDisplay: "/k/", exampleWord: "café", category: .consonant),
        .init(id: "g", ipaDisplay: "/g/", exampleWord: "gare", category: .consonant),
        .init(id: "f", ipaDisplay: "/f/", exampleWord: "fort", category: .consonant),
        .init(id: "v", ipaDisplay: "/v/", exampleWord: "vin", category: .consonant),
        .init(id: "s", ipaDisplay: "/s/", exampleWord: "sac", category: .consonant),
        .init(id: "z", ipaDisplay: "/z/", exampleWord: "zoo", category: .consonant),
        .init(id: "ʃ", ipaDisplay: "/ʃ/", exampleWord: "chat", category: .consonant),
        .init(id: "ʒ", ipaDisplay: "/ʒ/", exampleWord: "jour", category: .consonant),
        .init(id: "l", ipaDisplay: "/l/", exampleWord: "lune", category: .consonant),
        .init(id: "ʁ", ipaDisplay: "/ʁ/", exampleWord: "rue", category: .consonant),
        .init(id: "m", ipaDisplay: "/m/", exampleWord: "maman", category: .consonant),
        .init(id: "n", ipaDisplay: "/n/", exampleWord: "non", category: .consonant),
        .init(id: "ɲ", ipaDisplay: "/ɲ/", exampleWord: "montagne", category: .consonant),
        .init(id: "ŋ", ipaDisplay: "/ŋ/", exampleWord: "parking", category: .consonant)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Tap any sound to hear it.")
                    .font(.subheadline)
                    .foregroundStyle(Color(.secondaryLabel))
                    .frame(maxWidth: .infinity, alignment: .leading)

                filterBar

                if !filtered(oralVowels).isEmpty {
                    sectionBlock(
                        index: 1,
                        title: "Oral Vowels",
                        systemImage: "circle.grid.cross",
                        items: filtered(oralVowels),
                        columns: 4
                    )
                }

                if !filtered(nasalVowels).isEmpty {
                    sectionBlock(
                        index: 2,
                        title: "Nasal Vowels",
                        systemImage: "nose.fill",
                        items: filtered(nasalVowels),
                        columns: 4
                    )
                }

                if !filtered(semiVowels).isEmpty {
                    sectionBlock(
                        index: 3,
                        title: "Semi-Vowels",
                        systemImage: "waveform.path",
                        items: filtered(semiVowels),
                        columns: 4
                    )
                }

                if !filtered(consonants).isEmpty {
                    sectionBlock(
                        index: 4,
                        title: "Consonants",
                        systemImage: "bubble.left.and.bubble.right.fill",
                        items: filtered(consonants),
                        columns: 6
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 28)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("French Pronunciation")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    // Placeholder for future glossary / credits.
                } label: {
                    Image(systemName: "info.circle")
                        .foregroundStyle(Color.accentColor)
                }
                .accessibilityLabel("Information")
            }
        }
    }

    private var filterBar: some View {
        HStack(spacing: 8) {
            ForEach(SoundFilter.allCases) { mode in
                filterChip(mode)
            }
        }
    }

    private func filterChip(_ mode: SoundFilter) -> some View {
        let selected = filter == mode
        return Button {
            filter = mode
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon(for: mode))
                    .font(.caption.weight(.semibold))
                Text(mode.rawValue)
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(selected ? Color.white : Color.accentColor)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule(style: .continuous)
                    .fill(selected ? Color.accentColor : Color.clear)
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(
                        Color.accentColor.opacity(selected ? 0 : (colorScheme == .dark ? 0.55 : 0.35)),
                        lineWidth: selected ? 0 : 1
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func icon(for mode: SoundFilter) -> String {
        switch mode {
        case .all: return "square.grid.2x2"
        case .vowels: return "drop.fill"
        case .consonants: return "bubble.left.and.bubble.right"
        }
    }

    private func filtered(_ items: [Phoneme]) -> [Phoneme] {
        switch filter {
        case .all:
            return items
        case .vowels:
            return items.filter(\.category.isVowelFamily)
        case .consonants:
            return items.filter { $0.category == .consonant }
        }
    }

    private func sectionBlock(
        index: Int,
        title: String,
        systemImage: String,
        items: [Phoneme],
        columns: Int
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(Color.accentColor))
                Text("\(index). \(title)")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Color(.label))
            }

            let gridItems = Array(repeating: GridItem(.flexible(), spacing: 10), count: columns)
            LazyVGrid(columns: gridItems, spacing: 10) {
                ForEach(items) { item in
                    phonemeCard(item)
                }
            }
        }
    }

    private func phonemeCard(_ item: Phoneme) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(item.ipaDisplay.precomposedStringWithCanonicalMapping)
                .font(.title3)
                .foregroundStyle(Color.blue)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(item.exampleWord)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack {
                Spacer(minLength: 0)
                Button {
                    speakExample(item.exampleWord)
                } label: {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Color.accentColor))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Play \(item.exampleWord)")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color(.separator), lineWidth: colorScheme == .dark ? 0.75 : 0.5)
        )
        .shadow(
            color: colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.06),
            radius: colorScheme == .dark ? 6 : 4,
            x: 0,
            y: 2
        )
    }

    private func speakExample(_ word: String) {
        let trimmed = word.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if speechSynth.isSpeaking {
            speechSynth.stopSpeaking(at: .immediate)
        }
        prepareAudioSessionForFrenchTTS()
        let utterance = AVSpeechUtterance(string: trimmed)
        utterance.voice = Self.preferredFrenchVoice()
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.92
        speechSynth.speak(utterance)
    }

    private func prepareAudioSessionForFrenchTTS() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: [.duckOthers])
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

#Preview {
    NavigationStack {
        FrenchPronunciationToolView()
    }
}
