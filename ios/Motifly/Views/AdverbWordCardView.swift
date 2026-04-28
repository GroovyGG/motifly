import AVFoundation
import SwiftData
import SwiftUI

/// Detail card for adverb entries: type, formation, placement (prototype adverb card).
struct AdverbWordCardView: View {
    @Bindable var entry: VocabularyEntry
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme

    @StateObject private var mineCoordinator = MineRecordingCoordinator()

    @State private var memoryNote: String = ""
    @State private var typeFormationExpanded = true
    @State private var placementExpanded = true
    @State private var memorySupportExpanded = false

    @State private var speechSynth = AVSpeechSynthesizer()

    /// Orange-brown headword (mock accent).
    private var adverbAccentColor: Color {
        Color(red: 0.69, green: 0.36, blue: 0.16)
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
                typeFormationSection
                placementSection
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
                        .foregroundStyle(adverbAccentColor)
                    HStack(alignment: .center, spacing: 8) {
                        Text("Adverb")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color(.tertiarySystemFill)))
                        if entry.advIsInvariable == true {
                            Text("Invariable")
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
        let target = (entry.advExampleTargetForm ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let phrase = target.isEmpty ? entry.frenchLemma : target
        var s = AttributedString(french)
        if let range = s.range(of: phrase, options: .caseInsensitive) {
            s[range].foregroundColor = adverbAccentColor
            s[range].font = .callout.bold()
        }
        return Text(s)
    }

    private var typeFormationSection: some View {
        DisclosureGroup(isExpanded: $typeFormationExpanded) {
            VStack(alignment: .leading, spacing: 12) {
                if let typeLine = entry.advAdverbType?.trimmingCharacters(in: .whitespacesAndNewlines), !typeLine.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        sectionHeading("Type")
                        Text(displayAdverbType(typeLine))
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(adverbAccentColor)
                        if let hint = typeHint(for: typeLine) {
                            Text("Hint: \(hint)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if let formation = entry.advFormation?.trimmingCharacters(in: .whitespacesAndNewlines), !formation.isEmpty {
                    if let parts = splitFormationPlus(formation) {
                        HStack(alignment: .top, spacing: 12) {
                            formationCell(title: "Related form", body: parts.left, highlight: false)
                            formationCell(title: "Formation", body: parts.right, highlight: true)
                        }
                    } else {
                        formationCell(title: "Formation", body: formation, highlight: false)
                    }
                }
            }
            .padding(.top, 8)
        } label: {
            sectionHeading("Type & formation")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Human-readable type label (snake-ish CSV → short title case).
    private func displayAdverbType(_ raw: String) -> String {
        raw
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "/", with: " · ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func typeHint(for raw: String) -> String? {
        let t = raw.lowercased()
        if t.contains("manner") { return #"Answers “how?”"# }
        if t.contains("time") { return "Relates to when or how long" }
        if t.contains("place") { return "Relates to where or direction" }
        if t.contains("negat") { return "Negation or restriction" }
        if t.contains("frequency") || t.contains("degree") { return "Intensity or how often" }
        return nil
    }

    private func splitFormationPlus(_ s: String) -> (left: String, right: String)? {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let r = trimmed.range(of: " + ") else { return nil }
        let left = String(trimmed[..<r.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        let right = String(trimmed[r.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !left.isEmpty, !right.isEmpty else { return nil }
        return (left, "\(left) + \(right)")
    }

    private func formationCell(title: String, body: String, highlight: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Group {
                if highlight, let suffix = mentSuffix(from: body) {
                    highlightedFormationRule(full: body, suffix: suffix)
                } else {
                    Text(body)
                        .foregroundStyle(.primary)
                }
            }
            .font(.callout)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(cardSurfaceFill)
        )
    }

    /// If `full` ends with `suffix`, return suffix for highlighting; else nil.
    private func mentSuffix(from full: String) -> String? {
        let t = full.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.lowercased().hasSuffix("ment") {
            return "ment"
        }
        return nil
    }

    private func highlightedFormationRule(full: String, suffix: String) -> Text {
        var s = AttributedString(full)
        if let range = s.range(of: suffix, options: [.caseInsensitive, .backwards]) {
            s[range].foregroundColor = adverbAccentColor
            s[range].font = .callout.bold()
        }
        return Text(s)
    }

    private var placementSection: some View {
        DisclosureGroup(isExpanded: $placementExpanded) {
            VStack(alignment: .leading, spacing: 12) {
                if let pos = entry.advPlacementPosition?.trimmingCharacters(in: .whitespacesAndNewlines), !pos.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        sectionHeading("Position (seed)")
                        Text(pos.replacingOccurrences(of: "_", with: " "))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                if let note = entry.advPlacementNote?.trimmingCharacters(in: .whitespacesAndNewlines), !note.isEmpty {
                    Text(note)
                        .font(.callout)
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                HStack(alignment: .top, spacing: 12) {
                    placementExampleCell(
                        title: "Example",
                        line: entry.advPlacementExampleFront
                    )
                    placementExampleCell(
                        title: "Example",
                        line: entry.advPlacementExampleEnd
                    )
                }
            }
            .padding(.top, 8)
        } label: {
            sectionHeading("Placement")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func placementExampleCell(title: String, line: String?) -> some View {
        let text = (line ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            if text.isEmpty {
                Text("—")
                    .font(.callout)
                    .foregroundStyle(.tertiary)
            } else {
                highlightedPlacementLine(text)
                    .font(.callout)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.tertiarySystemFill))
        )
    }

    private func highlightedPlacementLine(_ french: String) -> Text {
        let target = (entry.advExampleTargetForm ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let phrase = target.isEmpty ? entry.frenchLemma : target
        var s = AttributedString(french)
        if let range = s.range(of: phrase, options: .caseInsensitive) {
            s[range].foregroundColor = adverbAccentColor
            s[range].font = .callout.bold()
        }
        return Text(s)
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
        seedNumber: 30_000_593,
        frenchLemma: "rapidement",
        english: "quickly, rapidly",
        pos: "adv",
        thematic: "none",
        exampleFrench: "ils ont passé rapidement dans l'histoire",
        exampleEnglish: "they disappeared quickly into history",
        entryKind: "adverb",
        chineseExplanation: "快速地",
        advAdverbType: "manner",
        advFormation: "derived -ment adverb",
        advIsInvariable: true,
        advPlacementPosition: "after_verb_or_verb_group",
        advPlacementNote: "Usually after the conjugated verb or after the whole verb group.",
        advPlacementExampleFront: "Il répond rapidement.",
        advPlacementExampleEnd: "Il a répondu rapidement.",
        advExampleTargetForm: "rapidement"
    )
    container.mainContext.insert(entry)
    return NavigationStack {
        AdverbWordCardView(entry: entry)
    }
    .modelContainer(container)
}
