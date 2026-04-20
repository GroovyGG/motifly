import AVFoundation
import SwiftData
import SwiftUI

/// Detail card for noun entries (v1 vocabulary), aligned with the design prototype.
struct NounWordCardView: View {
    @Bindable var entry: VocabularyEntry
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme

    @StateObject private var mineCoordinator = MineRecordingCoordinator()

    @State private var memoryNote: String = ""
    @State private var articlePluralExpanded = true
    @State private var memorySupportExpanded = false

    @State private var speechSynth = AVSpeechSynthesizer()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                headerBlock
                translationBlock
                exampleBlock
                articlePluralSection
                memorySupportSection
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
            mineCoordinator.configure(seedNumber: entry.seedNumber)
        }
        .onChange(of: entry.seedNumber) { _, new in
            mineCoordinator.configure(seedNumber: new)
        }
        .onDisappear {
            mineCoordinator.tearDownOnLeave()
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

    /// Warm note card in light mode; semantic grouped fill in dark mode (avoids harsh cream on dark UI).
    private var memorySupportCardBackground: Color {
        if colorScheme == .dark {
            return Color(.secondarySystemGroupedBackground)
        }
        return Color(red: 1, green: 0.96, blue: 0.82)
    }

    private var headerBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(entry.frenchLemma)
                        .font(.title.weight(.bold))
                        .foregroundStyle(lemmaDisplayColor)
                    Text(posLabel)
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color(.tertiarySystemFill)))
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                HStack(alignment: .center, spacing: 8) {
                    Button {
                        speakFrench(entry.frenchLemma)
                    } label: {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(Self.headerAudioIconFont)
                            .frame(width: Self.headerAudioButtonSide, height: Self.headerAudioButtonSide)
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.circle)
                    .tint(.secondary)
                    .accessibilityLabel("French")
                    .frame(width: Self.headerAudioControlOuter, height: Self.headerAudioControlOuter)

                    Button {
                        mineCoordinator.playMine()
                    } label: {
                        Image(systemName: "mic.fill")
                            .font(Self.headerAudioIconFont)
                            .frame(width: Self.headerAudioButtonSide, height: Self.headerAudioButtonSide)
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.circle)
                    .tint(.accentColor)
                    .disabled(!mineCoordinator.hasMineRecording)
                    .accessibilityLabel("Mine")
                    .frame(width: Self.headerAudioControlOuter, height: Self.headerAudioControlOuter)

                    Button {
                        Task { await mineCoordinator.toggleRecording() }
                    } label: {
                        Image(systemName: mineCoordinator.isRecording ? "stop.circle.fill" : "record.circle")
                            .font(Self.headerAudioIconFont)
                            .symbolRenderingMode(.monochrome)
                            .frame(width: Self.headerAudioButtonSide, height: Self.headerAudioButtonSide)
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.circle)
                    .tint(mineCoordinator.isRecording ? .red : .accentColor)
                    .accessibilityLabel(mineCoordinator.isRecording ? "Stop recording" : "Record my pronunciation")
                    .frame(width: Self.headerAudioControlOuter, height: Self.headerAudioControlOuter)
                }
            }

            if mineCoordinator.isRecording {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                    Text("Recording…")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.red)
                }
            }

            if mineCoordinator.awaitingSaveConfirmation {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Save this take as your Mine pronunciation?")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button {
                        mineCoordinator.playPendingRecording()
                    } label: {
                        Label("Replay take", systemImage: "play.circle.fill")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.bordered)
                    .tint(.accentColor)
                    HStack(spacing: 12) {
                        Button("Save to Mine") {
                            mineCoordinator.confirmSaveMine()
                        }
                        .font(.caption.weight(.semibold))
                        .buttonStyle(.borderedProminent)

                        Button("Discard", role: .cancel) {
                            mineCoordinator.discardPendingRecording()
                        }
                        .font(.caption.weight(.semibold))
                        .buttonStyle(.bordered)
                    }
                }
                .padding(.top, 4)
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
        VStack(alignment: .leading, spacing: 6) {
            translationPairRow(title: "English", text: entry.english)
            if let zh = entry.chineseExplanation,
               !zh.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Divider()
                    .opacity(0.35)
                translationPairRow(title: "中文", text: zh)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(cardSurfaceFill)
        )
    }

    private func translationPairRow(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(text)
                .font(.callout)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// Elevated surface on `systemGroupedBackground` so cards stay visible in light and dark mode.
    private var cardSurfaceFill: Color {
        Color(.secondarySystemGroupedBackground)
    }

    /// Matches the gray label style used for “English”, “中文”, and section headings.
    private func sectionHeading(_ title: String) -> some View {
        Text(title)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
    }

    private var exampleBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionHeading("Example sentence")
            if !entry.exampleFrench.isEmpty {
                highlightedExample(french: entry.exampleFrench, lemma: entry.frenchLemma, color: lemmaDisplayColor)
                    .font(.callout)
            }
            if !entry.exampleEnglish.isEmpty {
                Text(entry.exampleEnglish)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(cardSurfaceFill)
        )
    }

    private var articlePluralSection: some View {
        DisclosureGroup(isExpanded: $articlePluralExpanded) {
            HStack(alignment: .top, spacing: 12) {
                articleCard
                pluralCard
            }
            .padding(.top, 4)
        } label: {
            sectionHeading("Article & plural")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var articleCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Article")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            if let art = entry.lemmaArticle, !art.isEmpty {
                Text("\(art) \(entry.frenchLemma)")
                    .font(.callout)
                if let indef = indefiniteSingularLine() {
                    Text(indef)
                        .font(.callout)
                }
            } else {
                Text("—")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(cardSurfaceFill)
        )
    }

    private var pluralCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Plural")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            if let pl = entry.pluralForm, !pl.isEmpty {
                Text(pluralWithDefiniteArticle(pl))
                    .font(.callout)
                if let pt = entry.pluralType, !pt.isEmpty {
                    Text(pt)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("—")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(cardSurfaceFill)
        )
    }

    /// Indefinite singular (un / une) when gender is known.
    private func indefiniteSingularLine() -> String? {
        let g = (entry.genderCode ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let indef = (g == "f" || entry.pos.lowercased().contains("nf")) ? "une" : (g == "m" || entry.pos.lowercased().contains("nm")) ? "un" : nil
        guard let indef else { return nil }
        return "\(indef) \(entry.frenchLemma)"
    }

    /// "les …" line for display when article + lemma pattern fits.
    private func pluralWithDefiniteArticle(_ pluralLemma: String) -> String {
        let g = (entry.genderCode ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let les = (g == "f" || entry.pos.lowercased().contains("nf")) || (g == "m" || entry.pos.lowercased().contains("nm"))
        if les {
            return "les \(pluralLemma)"
        }
        return pluralLemma
    }

    private var memorySupportSection: some View {
        DisclosureGroup(isExpanded: $memorySupportExpanded) {
            HStack(alignment: .top, spacing: 12) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(.tertiarySystemFill))
                    .aspectRatio(1, contentMode: .fit)
                    .frame(maxWidth: 120)
                    .overlay {
                        VStack(spacing: 6) {
                            Image(systemName: "photo")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                            Text("Image")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .accessibilityLabel("Memory image placeholder")

                TextField("Add a memory hook…", text: $memoryNote, axis: .vertical)
                    .font(.callout)
                    .lineLimit(5...12)
                    .padding(10)
                    .frame(maxWidth: .infinity, minHeight: 88, alignment: .topLeading)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(cardSurfaceFill)
                    )
                    .onChange(of: memoryNote) { _, new in
                        saveMemoryNote(new)
                    }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(memorySupportCardBackground)
            )
            .padding(.top, 4)
        } label: {
            sectionHeading("Memory support")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var progressPlaceholder: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeading("Progress")
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
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.callout.weight(.bold))
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
            sectionHeading("Errored attempts")
            Text("No spelling mistakes recorded yet.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func highlightedExample(french: String, lemma: String, color: Color) -> Text {
        var s = AttributedString(french)
        if let range = s.range(of: lemma, options: String.CompareOptions.caseInsensitive) {
            s[range].foregroundColor = color
            s[range].font = .callout.bold()
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

    /// Icon area inside each header audio control (keep at 30).
    private static let headerAudioButtonSide: CGFloat = 30
    /// Outer layout box for bordered circular buttons around `headerAudioButtonSide`.
    private static let headerAudioControlOuter: CGFloat = 36
    private static let headerAudioIconFont = Font.callout

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
