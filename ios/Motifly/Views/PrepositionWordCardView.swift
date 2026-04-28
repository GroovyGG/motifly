import AVFoundation
import SwiftData
import SwiftUI

/// Detail card for preposition entries (`seed_prepositions.csv`). Shell matches noun / verb / adjective cards (header, translation, example, audio controls).
struct PrepositionWordCardView: View {
    @Bindable var entry: VocabularyEntry
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme

    @StateObject private var mineCoordinator = MineRecordingCoordinator()

    @State private var memoryNote: String = ""
    @State private var coreMeaningExpanded = true
    @State private var patternExpanded = true
    @State private var collocationsExpanded = true
    @State private var detailsExpanded = false
    @State private var memorySupportExpanded = false

    @State private var speechSynth = AVSpeechSynthesizer()

    private var prepAccentColor: Color {
        Color(red: 0.96, green: 0.48, blue: 0.12)
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
                coreMeaningSection
                patternSection
                collocationsSection
                detailsSection
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

    // MARK: - Header (same control layout as Noun / Adjective / Verb)

    private var headerBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(entry.frenchLemma)
                        .font(.title.weight(.bold))
                        .foregroundStyle(prepAccentColor)
                    HStack(alignment: .center, spacing: 8) {
                        Text("Preposition")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color(.tertiarySystemFill)))
                        if entry.prepIsFunctionWord == true {
                            Text("Function word")
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(Color(.tertiarySystemFill)))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
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

    // MARK: - Translation (same as noun card)

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

    // MARK: - Example (same shell as noun card)

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
        let target = (entry.prepExampleTargetForm ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let phrase = target.isEmpty ? entry.frenchLemma : target
        var s = AttributedString(french)
        if let range = s.range(of: phrase, options: .caseInsensitive) {
            s[range].foregroundColor = prepAccentColor
            s[range].font = .callout.bold()
        }
        return Text(s)
    }

    // MARK: - Core meaning

    private var coreMeaningSection: some View {
        let core = (entry.prepCoreMeaning ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return Group {
            if !core.isEmpty {
                DisclosureGroup(isExpanded: $coreMeaningExpanded) {
                    VStack(alignment: .leading, spacing: 10) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Core function")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Text(core)
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(prepAccentColor)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(cardSurfaceFill)
                        )

                        if let note = entry.prepUsageNote?.trimmingCharacters(in: .whitespacesAndNewlines), !note.isEmpty {
                            Text(note)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.top, 8)
                } label: {
                    sectionHeading("Core meaning")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Patterns

    private var patternSection: some View {
        let lines = patternLines
        return Group {
            if !lines.isEmpty {
                DisclosureGroup(isExpanded: $patternExpanded) {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(lines, id: \.self) { line in
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
                    .padding(.top, 8)
                } label: {
                    sectionHeading("Pattern")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var patternLines: [String] {
        [entry.prepPattern1, entry.prepPattern2, entry.prepPattern3]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    // MARK: - Collocations

    private var collocationsSection: some View {
        Group {
            if !collocationLines.isEmpty {
                DisclosureGroup(isExpanded: $collocationsExpanded) {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(collocationLines, id: \.self) { line in
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
                    .padding(.top, 8)
                } label: {
                    sectionHeading("Common collocations")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var collocationLines: [String] {
        let raw = (entry.prepCommonCollocationsRaw ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return [] }
        return raw.split(separator: "|")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    // MARK: - Details (seed type + memory tip)

    private var detailsSection: some View {
        let typeLine = entry.prepPrepositionType?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let mem = entry.prepMemoryNote?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return Group {
            if !typeLine.isEmpty || !mem.isEmpty {
                DisclosureGroup(isExpanded: $detailsExpanded) {
                    VStack(alignment: .leading, spacing: 12) {
                        if !typeLine.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                sectionHeading("Preposition type")
                                Text(typeLine)
                                    .font(.callout)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        if !mem.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                sectionHeading("Memory tip (seed)")
                                Text(mem)
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                    .padding(.top, 8)
                } label: {
                    sectionHeading("Details")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Memory support (same as noun card)

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
        seedNumber: 60_000_004,
        frenchLemma: "à",
        english: "to, at, in",
        pos: "prep",
        thematic: "none",
        exampleFrench: "Je vais à Montréal.",
        exampleEnglish: "I'm going to Montreal.",
        entryKind: "preposition",
        chineseExplanation: "到；在；用于地点、方向、关系",
        prepPrepositionType: "simple preposition",
        prepIsFunctionWord: true,
        prepCoreMeaning: "direction / location / relation",
        prepPattern1: "à + city: à Paris",
        prepPattern2: "à + noun: à la maison",
        prepPattern3: "verb + à: penser à, parler à",
        prepCommonCollocationsRaw: "aller à | penser à | donner à",
        prepUsageNote: "À often marks destination, location, time, or an indirect relation.",
        prepMemoryNote: "Memorize à with the surrounding words.",
        prepExampleTargetForm: "à"
    )
    container.mainContext.insert(entry)
    return NavigationStack {
        PrepositionWordCardView(entry: entry)
    }
    .modelContainer(container)
}
