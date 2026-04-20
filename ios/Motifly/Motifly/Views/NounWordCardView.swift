import AVFoundation
import SwiftData
import SwiftUI

/// Detail card for noun entries (v1 vocabulary), aligned with the design prototype.
struct NounWordCardView: View {
    @Bindable var entry: VocabularyEntry
    @Environment(\.modelContext) private var modelContext

    @State private var articlePluralExpanded = true
    @State private var memoryExpanded = false
    @State private var memoryNote: String = ""

    @State private var speechSynth = AVSpeechSynthesizer()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerBlock
                translationBlock
                exampleBlock
                DisclosureGroup(isExpanded: $articlePluralExpanded) {
                    articlePluralContent
                } label: {
                    Label("Article & plural", systemImage: "text.book.closed")
                        .font(.headline)
                }
                DisclosureGroup(isExpanded: $memoryExpanded) {
                    TextField("Add a memory hook…", text: $memoryNote, axis: .vertical)
                        .lineLimit(3...8)
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color(.tertiarySystemGroupedBackground)))
                        .onChange(of: memoryNote) { _, new in
                            saveMemoryNote(new)
                        }
                } label: {
                    Label("Memory support", systemImage: "brain.head.profile")
                        .font(.headline)
                }
                progressPlaceholder
                erroredAttemptsPlaceholder
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            SearchHistoryService.recordSearch(modelContext: modelContext, seedNumber: entry.seedNumber)
            memoryNote = UserDefaults.standard.string(forKey: memoryKey) ?? ""
        }
    }

    private var memoryKey: String {
        "motifly.vocab.memory.\(entry.seedNumber)"
    }

    private func saveMemoryNote(_ text: String) {
        UserDefaults.standard.set(text, forKey: memoryKey)
    }

    private var lemmaDisplayColor: Color {
        NounWordCardView.lemmaColor(genderCode: entry.genderCode ?? "", pos: entry.pos)
    }

    private var headerBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Text("📖")
                    .font(.title)
                VStack(alignment: .leading, spacing: 8) {
                    Text(entry.frenchLemma)
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(lemmaDisplayColor)
                    HStack(spacing: 8) {
                        Text(posLabel)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color(.tertiarySystemFill)))
                        Button {
                            speakFrench(entry.frenchLemma)
                        } label: {
                            Label("French", systemImage: "speaker.wave.2.fill")
                                .font(.caption.weight(.semibold))
                        }
                        .buttonStyle(.bordered)
                        .tint(.secondary)
                        Button {
                            // Recording hook for a later milestone.
                        } label: {
                            Label("Mine", systemImage: "mic.fill")
                                .font(.caption.weight(.semibold))
                        }
                        .buttonStyle(.bordered)
                        .tint(.secondary)
                        .disabled(true)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    private var posLabel: String {
        let p = entry.pos.lowercased()
        if p.contains("nm") || p.contains("nf") || p.contains("nmi") || p.contains("nc") || p.contains("nf(pl)") {
            return "Noun"
        }
        return "Word"
    }

    private var translationBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            labeledBox(title: "English", text: entry.english)
            if let zh = entry.chineseExplanation,
               !zh.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                labeledBox(title: "中文", text: zh)
            }
        }
    }

    private func labeledBox(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(text)
                .font(.body)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.systemBackground))
        )
    }

    private var exampleBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Example sentence")
                .font(.headline)
            if !entry.exampleFrench.isEmpty {
                highlightedExample(french: entry.exampleFrench, lemma: entry.frenchLemma, color: lemmaDisplayColor)
                    .font(.body)
            }
            if !entry.exampleEnglish.isEmpty {
                Text(entry.exampleEnglish)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.systemBackground))
        )
    }

    private var articlePluralContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let art = entry.lemmaArticle, !art.isEmpty {
                Text("Singular: \(art) \(entry.frenchLemma)")
                    .font(.body)
            }
            if let pl = entry.pluralForm, !pl.isEmpty {
                Text("Plural: \(pl)")
                    .font(.body)
            }
            if let pt = entry.pluralType, !pt.isEmpty {
                Text(pt)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 6)
    }

    private var progressPlaceholder: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Progress")
                .font(.headline)
            HStack(spacing: 12) {
                metricChip(title: "Accuracy", value: "—")
                metricChip(title: "Attempts", value: "—")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func metricChip(title: String, value: String) -> some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.bold))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.tertiarySystemGroupedBackground))
        )
    }

    private var erroredAttemptsPlaceholder: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Errored attempts")
                .font(.headline)
            Text("No spelling mistakes recorded yet.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func highlightedExample(french: String, lemma: String, color: Color) -> Text {
        var s = AttributedString(french)
        if let range = s.range(of: lemma, options: String.CompareOptions.caseInsensitive) {
            s[range].foregroundColor = color
            s[range].font = .body.bold()
        }
        return Text(s)
    }

    /// Uses on-device TTS. `fr-FR` is France French; falls back to another installed `fr-*` voice if needed.
    private func speakFrench(_ text: String) {
        if speechSynth.isSpeaking {
            speechSynth.stopSpeaking(at: .immediate)
        }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = Self.preferredFrenchVoice()
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.92
        speechSynth.speak(utterance)
    }

    private static func preferredFrenchVoice() -> AVSpeechSynthesisVoice? {
        if let frFR = AVSpeechSynthesisVoice(language: "fr-FR") {
            return frFR
        }
        return AVSpeechSynthesisVoice.speechVoices().first { $0.language.hasPrefix("fr") }
    }

    static func lemmaColor(genderCode: String, pos: String) -> Color {
        let g = genderCode.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let p = pos.lowercased()
        if g == "f" || p.contains("nf") {
            return Color(red: 0.78, green: 0.28, blue: 0.42)
        }
        if g == "m" || p.contains("nm") {
            return Color(red: 0.18, green: 0.32, blue: 0.62)
        }
        return Color.primary
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: VocabularyEntry.self,
        SearchHistoryEntry.self,
        configurations: config
    )
    let entry = VocabularyEntry(
        seedNumber: 1,
        frenchLemma: "voiture",
        english: "car",
        pos: "nf",
        thematic: "Travel",
        exampleFrench: "Ma voiture est bleue.",
        exampleEnglish: "My car is blue.",
        chineseExplanation: "汽车",
        genderCode: "f",
        lemmaArticle: "la",
        pluralForm: "voitures",
        pluralType: "regular -s"
    )
    container.mainContext.insert(entry)
    return NavigationStack {
        NounWordCardView(entry: entry)
    }
    .modelContainer(container)
}
