import AVFoundation
import SwiftData
import SwiftUI

/// Detail card for determiner entries: type, agreement grid, noun patterns (prototype determiner card).
struct DeterminerWordCardView: View {
    @Bindable var entry: VocabularyEntry
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme

    @StateObject private var mineCoordinator = MineRecordingCoordinator()

    @State private var memoryNote: String = ""
    @State private var determinerTypeExpanded = true
    @State private var agreementExpanded = true
    @State private var nounPatternExpanded = true
    @State private var memorySupportExpanded = false

    @State private var speechSynth = AVSpeechSynthesizer()

    /// Dark teal headword and example highlight (mock).
    private var determinerAccentColor: Color {
        Color(red: 0.11, green: 0.42, blue: 0.45)
    }

    private var mascAgreementColor: Color {
        Color(red: 0.18, green: 0.32, blue: 0.62)
    }

    private var femAgreementColor: Color {
        Color(red: 0.78, green: 0.28, blue: 0.42)
    }

    private var memorySupportCardBackground: Color {
        if colorScheme == .dark {
            return Color(.secondarySystemGroupedBackground)
        }
        return Color(red: 1, green: 0.96, blue: 0.82)
    }

    private var cardSurfaceFill: Color {
        Color(.secondarySystemGroupedBackground)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                headerBlock
                translationBlock
                exampleBlock
                determinerTypeSection
                agreementSection
                nounPatternSection
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

    private func sectionHeading(_ title: String) -> some View {
        Text(title)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
    }

    private var headerBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(entry.frenchLemma)
                        .font(.title.weight(.bold))
                        .foregroundStyle(determinerAccentColor)
                    Text("Determiner")
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
                .layoutPriority(1)
                .zIndex(1)
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

    private var exampleBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionHeading("Example sentence")
            if !entry.exampleFrench.isEmpty {
                highlightedExampleFrench()
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

    private func highlightedExampleFrench() -> Text {
        let french = entry.exampleFrench
        let target = (entry.detExampleTargetForm ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let phrase = target.isEmpty ? entry.frenchLemma : target
        var s = AttributedString(french)
        if let range = s.range(of: phrase, options: .caseInsensitive) {
            s[range].foregroundColor = determinerAccentColor
            s[range].font = .callout.bold()
        }
        return Text(s)
    }

    private var determinerTypeSection: some View {
        DisclosureGroup(isExpanded: $determinerTypeExpanded) {
            VStack(alignment: .leading, spacing: 8) {
                sectionHeading("Type")
                if let t = entry.detDeterminerType?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty {
                    Text(t)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(determinerAccentColor)
                }
                if let note = entry.detUsageNote?.trimmingCharacters(in: .whitespacesAndNewlines), !note.isEmpty {
                    Text(note)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 8)
        } label: {
            sectionHeading("Determiner type")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var agreementSection: some View {
        DisclosureGroup(isExpanded: $agreementExpanded) {
            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
                spacing: 12
            ) {
                agreementCell(
                    title: "Masculine singular",
                    value: entry.detMascSingular,
                    tint: mascAgreementColor
                )
                agreementCell(
                    title: "Feminine singular",
                    value: entry.detFemSingular,
                    tint: femAgreementColor
                )
                agreementCell(
                    title: "Masculine plural",
                    value: entry.detMascPlural,
                    tint: mascAgreementColor
                )
                agreementCell(
                    title: "Feminine plural",
                    value: entry.detFemPlural,
                    tint: femAgreementColor
                )
            }
            .padding(.top, 8)
        } label: {
            sectionHeading("Agreement forms")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func agreementCell(title: String, value: String?, tint: Color) -> some View {
        let display = (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let text = display.isEmpty ? "—" : display
        return VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(tint.opacity(0.88))
            Text(text)
                .font(.title3.weight(.semibold))
                .foregroundStyle(display.isEmpty ? .secondary : tint)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(cardSurfaceFill)
        )
    }

    private var nounPatternSection: some View {
        DisclosureGroup(isExpanded: $nounPatternExpanded) {
            VStack(alignment: .leading, spacing: 8) {
                if nounPatternLines.isEmpty {
                    Text("—")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(nounPatternLines, id: \.self) { line in
                        Text(line)
                            .font(.callout)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color(.tertiarySystemFill))
                            )
                    }
                }
            }
            .padding(.top, 8)
        } label: {
            sectionHeading("Noun pattern")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var nounPatternLines: [String] {
        let raw = (entry.detNounPatternsRaw ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return [] }
        return raw.split(separator: "|")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
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

    private func prepareAudioSessionForFrenchTTS() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try session.setActive(true, options: [])
        } catch {
            try? session.setActive(true, options: [])
        }
    }

    private func speakFrench(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if speechSynth.isSpeaking {
            speechSynth.stopSpeaking(at: .immediate)
        }
        if !mineCoordinator.isRecording {
            prepareAudioSessionForFrenchTTS()
        }
        let utterance = AVSpeechUtterance(string: trimmed)
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

    private static let headerAudioButtonSide: CGFloat = 24
    private static let headerAudioControlOuter: CGFloat = 36
    private static let headerAudioIconFont = Font.callout
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: VocabularyEntry.self,
        SearchHistoryEntry.self,
        configurations: config
    )
    let entry = VocabularyEntry(
        seedNumber: 40_000_012,
        frenchLemma: "ce",
        english: "this, that",
        pos: "det,pro",
        thematic: "none",
        exampleFrench: "Ce livre est intéressant.",
        exampleEnglish: "这本书很有趣。",
        entryKind: "determiner",
        chineseExplanation: "这个，那个；这些，那些",
        detDeterminerType: "demonstrative determiner",
        detUsageNote: "used before a noun to point to this/that thing",
        detMascSingular: "ce / cet",
        detFemSingular: "cette",
        detMascPlural: "ces",
        detFemPlural: "ces",
        detNounPatternsRaw:
            "ce + masculine noun|cet + masculine noun starting with vowel/silent h|cette + feminine noun|ces + plural noun",
        detExampleTargetForm: "Ce"
    )
    container.mainContext.insert(entry)
    return NavigationStack {
        DeterminerWordCardView(entry: entry)
    }
    .modelContainer(container)
}
