import AVFoundation
import SwiftData
import SwiftUI

private struct ConjugationPair: Codable {
    let person: String
    let form: String
}

/// Detail card for verb entries (conjugation + shared shell).
struct VerbWordCardView: View {
    @Bindable var entry: VocabularyEntry
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme

    @StateObject private var mineCoordinator = MineRecordingCoordinator()

    @State private var memoryNote: String = ""
    @State private var coreFormsExpanded = false
    @State private var presentExpanded = true
    @State private var passeExpanded = true
    @State private var memorySupportExpanded = false

    @State private var speechSynth = AVSpeechSynthesizer()

    /// Verbs have no masculine/feminine split — use one green for the headword everywhere (prototype `text-green-700`).
    private var lemmaDisplayColor: Color {
        if colorScheme == .dark {
            return Color(red: 0.38, green: 0.82, blue: 0.55)
        }
        return Color(red: 0.09, green: 0.50, blue: 0.26)
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
                coreFormsSection
                presentTenseSection
                Divider()
                    .opacity(0.35)
                passeComposeSection
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
                        .foregroundStyle(lemmaDisplayColor)
                    HStack(alignment: .center, spacing: 8) {
                        Text("Verb")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color(.tertiarySystemFill)))
                        if let g = entry.verbGroup, !g.isEmpty {
                            Text(g)
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(Color(.tertiarySystemFill)))
                        }
                        if let a = entry.verbAuxiliary, !a.isEmpty {
                            Text("aux: \(a)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
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

    /// e.g. `avoir + parlé` when both auxiliary and past participle exist (prototype “Passé composé helper”).
    private var passeComposeHelperDisplay: String {
        let pp = (entry.verbPastParticiple ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let aux = (entry.verbAuxiliary ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !aux.isEmpty, !pp.isEmpty { return "\(aux) + \(pp)" }
        if !pp.isEmpty { return pp }
        return "—"
    }

    private var coreFormsSection: some View {
        DisclosureGroup(isExpanded: $coreFormsExpanded) {
            HStack(alignment: .top, spacing: 12) {
                coreFormInfinitiveCard
                coreFormPasseComposeHelperCard
            }
            .padding(.top, 4)
        } label: {
            sectionHeading("Core Forms")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var coreFormInfinitiveCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Infinitive")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(entry.frenchLemma)
                .font(.title3.weight(.semibold))
                .foregroundStyle(lemmaDisplayColor)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(cardSurfaceFill)
        )
    }

    private var coreFormPasseComposeHelperCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Passé composé helper")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(passeComposeHelperDisplay)
                .font(.title3.weight(.semibold))
                .foregroundStyle(passeComposeHelperDisplay == "—" ? .secondary : .primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(cardSurfaceFill)
        )
    }

    private var presentTenseSection: some View {
        DisclosureGroup(isExpanded: $presentExpanded) {
            conjugationMiniTable(json: entry.verbPresentJSON)
                .padding(.top, 8)
        } label: {
            sectionHeading("Present Tense Mini Table")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var passeComposeSection: some View {
        DisclosureGroup(isExpanded: $passeExpanded) {
            conjugationMiniTable(json: entry.verbPasseComposeJSON)
                .padding(.top, 8)
        } label: {
            sectionHeading("Passé Composé Mini Table")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Two-column × three-row grid of pills: pronoun (muted) + form (bold) per cell.
    private func conjugationMiniTable(json: String?) -> some View {
        let pairs = decodePairs(json)
        return Group {
            if pairs.isEmpty {
                Text("No forms in seed data.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(cardSurfaceFill)
                    )
            } else {
                let rows = Self.pairedRows(from: pairs)
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                        HStack(alignment: .top, spacing: 8) {
                            ForEach(0..<row.count, id: \.self) { idx in
                                let pair = row[idx]
                                conjugationPill(person: pair.person, form: pair.form)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            if row.count == 1 {
                                Spacer(minLength: 0)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(cardSurfaceFill)
                )
            }
        }
    }

    private func conjugationPill(person: String, form: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(person)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
            Spacer(minLength: 4)
            Text(form)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.trailing)
                .lineLimit(3)
                .minimumScaleFactor(0.75)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.tertiarySystemGroupedBackground))
        )
    }

    /// Pairs consecutive persons into rows of two (je+tu | il/elle+nous | vous+ils/elles).
    private static func pairedRows(from pairs: [ConjugationPair]) -> [[ConjugationPair]] {
        var rows: [[ConjugationPair]] = []
        var i = 0
        while i < pairs.count {
            if i + 1 < pairs.count {
                rows.append([pairs[i], pairs[i + 1]])
                i += 2
            } else {
                rows.append([pairs[i]])
                i += 1
            }
        }
        return rows
    }

    private func decodePairs(_ json: String?) -> [ConjugationPair] {
        guard let json, let data = json.data(using: .utf8),
              let pairs = try? JSONDecoder().decode([ConjugationPair].self, from: data) else {
            return []
        }
        return pairs
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
        if let range = s.range(of: lemma, options: .caseInsensitive) {
            s[range].foregroundColor = color
            s[range].font = .callout.bold()
        }
        return Text(s)
    }

    /// TTS needs an active playback session; mic/teardown can leave the session inactive so French is silent.
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

    private static let headerAudioButtonSide: CGFloat = 30
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
    let present = #"[{"person":"je","form":"suis"},{"person":"tu","form":"es"}]"#
    let pc = #"[{"person":"je","form":"ai été"}]"#
    let entry = VocabularyEntry(
        seedNumber: 10_000_005,
        frenchLemma: "être",
        english: "to be",
        pos: "v",
        thematic: "none",
        exampleFrench: "c'est bien",
        exampleEnglish: "that's good",
        entryKind: "verb",
        chineseExplanation: "是",
        verbGroup: "3e groupe",
        verbAuxiliary: "avoir",
        verbPastParticiple: "été",
        verbPresentJSON: present,
        verbPasseComposeJSON: pc
    )
    container.mainContext.insert(entry)
    return NavigationStack {
        VerbWordCardView(entry: entry)
    }
    .modelContainer(container)
}
