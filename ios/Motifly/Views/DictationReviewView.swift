import SwiftData
import SwiftUI

struct DictationReviewView: View {
    enum SortMode: String, CaseIterable, Identifiable {
        case weakFirst = "Weak First"
        case seedAscending = "Default"

        var id: String { rawValue }
    }

    let unitIndex: Int
    let words: [VocabularyEntry]

    @Environment(\.modelContext) private var modelContext
    @Query private var wordStats: [DictationWordStats]
    @StateObject private var playbackEngine = DictationPlaybackEngine()
    @State private var sortMode: SortMode = .weakFirst

    private var statsBySeed: [Int: DictationWordStats] {
        Dictionary(uniqueKeysWithValues: wordStats.map { ($0.seedNumber, $0) })
    }

    private var sortedWords: [VocabularyEntry] {
        switch sortMode {
        case .seedAscending:
            return words.sorted { $0.seedNumber < $1.seedNumber }
        case .weakFirst:
            return words.sorted { lhs, rhs in
                let left = historyPercent(for: lhs) ?? -1
                let right = historyPercent(for: rhs) ?? -1
                if left == right {
                    return lhs.seedNumber < rhs.seedNumber
                }
                return left < right
            }
        }
    }

    private var averageAccuracyText: String {
        "\(averageAccuracyValue)%"
    }

    private var weakWordsCount: Int {
        words.reduce(into: 0) { count, word in
            guard let s = statsBySeed[word.seedNumber] else { return }
            if s.wrongCount > s.correctCount {
                count += 1
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                startDictationButton
                summaryCard
                previewHeader
                LazyVStack(spacing: 8) {
                    ForEach(Array(sortedWords.enumerated()), id: \.element.seedNumber) { offset, word in
                        NavigationLink {
                            wordCard(for: word)
                        } label: {
                            previewRow(index: offset + 1, word: word)
                        }
                        .buttonStyle(.plain)
                        .simultaneousGesture(
                            TapGesture().onEnded {
                                StudyEventLogger.record(
                                    modelContext: modelContext,
                                    seedNumber: word.seedNumber,
                                    eventType: StudyEventType.reviewWordOpen,
                                    context: [
                                        "screen": "dictation_review",
                                        "unit": String(unitIndex + 1)
                                    ]
                                )
                            }
                        )
                    }
                }
            }
            .padding(16)
            .padding(.bottom, 20)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Word Group Preview")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Image(systemName: "info.circle")
                    .foregroundStyle(.blue)
            }
        }
        .onDisappear {
            playbackEngine.stopCurrentPlayback()
        }
    }

    private var startDictationButton: some View {
        NavigationLink {
            DictationSessionView(
                unitIndex: max(0, unitIndex),
                words: words
            )
        } label: {
            HStack {
                Text("Start Dictation")
                    .font(.caption.weight(.semibold))
                Spacer()
                Image(systemName: "play.fill")
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .frame(height: 36)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.blue)
            )
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            TapGesture().onEnded {
                StudyEventLogger.record(
                    modelContext: modelContext,
                    seedNumber: 0,
                    eventType: StudyEventType.reviewStartDictationTap,
                    context: [
                        "screen": "dictation_review",
                        "unit": String(unitIndex + 1),
                        "wordCount": String(words.count)
                    ]
                )
            }
        )
    }

    private var summaryCard: some View {
        HStack(spacing: 0) {
            accuracyRingMetric
            Divider()
            summaryMetric(
                icon: "square.stack.3d.up.fill",
                value: "\(words.count)",
                titleLine1: "words",
                titleLine2: "in this group"
            )
            Divider()
            summaryMetric(
                value: "\(weakWordsCount)",
                titleLine1: "weak words",
                titleLine2: "need review"
            )
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 108)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    private var accuracyRingMetric: some View {
        VStack(spacing: 2) {
            ZStack {
                Circle()
                    .stroke(Color.blue.opacity(0.15), lineWidth: 6)
                    .frame(width: 58, height: 58)
                Circle()
                    .trim(from: 0, to: max(0, min(1, Double(averageAccuracyValue) / 100.0)))
                    .stroke(Color.blue, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 58, height: 58)
                Text(averageAccuracyText)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.blue)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func summaryMetric(icon: String? = nil, value: String, titleLine1: String, titleLine2: String) -> some View {
        VStack(spacing: 2) {
            if let icon {
                Image(systemName: icon)
                    .font(.subheadline)
                    .foregroundStyle(.blue)
            } else {
                Spacer()
                    .frame(height: 0)
            }
            Text(value)
                .font(.title3.weight(.medium))
                .foregroundStyle(.blue)
            Text("\(titleLine1) \(titleLine2)")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }

    private var previewHeader: some View {
        HStack {
            Text("Preview (\(words.count) items)")
                .font(.subheadline.weight(.semibold))
            Spacer()
            Menu {
                ForEach(SortMode.allCases) { mode in
                    Button(mode.rawValue) {
                        sortMode = mode
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text("Sort")
                    Image(systemName: "line.3.horizontal.decrease")
                }
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.blue)
            }
        }
    }

    private func previewRow(index: Int, word: VocabularyEntry) -> some View {
        HStack(spacing: 10) {
            Text("\(index)")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.blue)
                .frame(width: 30, height: 30)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.blue.opacity(0.08))
                )

            VStack(alignment: .leading, spacing: 1) {
                Text(word.frenchLemma)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                Text(word.english)
                    .font(.caption2.weight(.medium))
                    .lineLimit(1)
                Text(word.chineseExplanation ?? "—")
                    .font(.system(size: 10))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider()
                .frame(height: 48)

            masteryColumn(for: word)

            VStack(spacing: 6) {
                rowIconButton(systemName: "speaker.wave.2.fill") {
                    play(word: word, source: .tts)
                }
                rowIconButton(systemName: "mic.fill", isEnabled: hasMineRecording(for: word)) {
                    play(word: word, source: .mine)
                }
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    @ViewBuilder
    private func wordCard(for e: VocabularyEntry) -> some View {
        switch e.entryKind {
        case "verb":
            VerbWordCardView(entry: e)
        case "adjective":
            AdjectiveWordCardView(entry: e)
        case "adverb":
            AdverbWordCardView(entry: e)
        case "determiner":
            DeterminerWordCardView(entry: e)
        case "pronoun":
            PronounWordCardView(entry: e)
        case "preposition":
            PrepositionWordCardView(entry: e)
        default:
            NounWordCardView(entry: e)
        }
    }

    private func rowIconButton(systemName: String, isEnabled: Bool = true, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(isEnabled ? .blue : .gray)
                .frame(width: 26, height: 26)
                .background(
                    Circle().stroke(
                        isEnabled ? Color.blue.opacity(0.2) : Color.gray.opacity(0.35),
                        lineWidth: 1
                    )
                )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }

    private func historyPercent(for word: VocabularyEntry) -> Int? {
        guard let s = statsBySeed[word.seedNumber], s.attemptCount > 0 else { return nil }
        return Int((Double(s.correctCount) / Double(s.attemptCount) * 100.0).rounded())
    }

    /// V1 memory model display: prefer overallMastery, fall back to historical accuracy
    /// while users still have words on the legacy stats path.
    private func masteryPercent(for word: VocabularyEntry) -> Int? {
        if let mastery = statsBySeed[word.seedNumber]?.overallMastery {
            return Int(mastery.rounded())
        }
        return historyPercent(for: word)
    }

    private func mainWeakness(for word: VocabularyEntry) -> String? {
        statsBySeed[word.seedNumber]?.mainWeakness
    }

    @ViewBuilder
    private func masteryColumn(for word: VocabularyEntry) -> some View {
        let percent = masteryPercent(for: word)
        VStack(alignment: .leading, spacing: 3) {
            Text(percent.map { "\($0)%" } ?? "—")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.blue)
            Capsule()
                .fill(Color.blue.opacity(0.18))
                .frame(width: 44, height: 4)
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(Color.blue)
                        .frame(width: 44 * CGFloat(Double(percent ?? 0) / 100.0), height: 4)
                }
            if let weakness = mainWeakness(for: word) {
                Text(DictationErrorKind.weaknessDisplayName(forStored: weakness))
                    .font(.system(size: 9).weight(.semibold))
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(
                        Capsule().fill(Color.orange.opacity(0.15))
                    )
            }
        }
        .frame(width: 60, alignment: .leading)
    }

    private func play(word: VocabularyEntry, source: DictationPlaybackSource) {
        StudyEventLogger.record(
            modelContext: modelContext,
            seedNumber: word.seedNumber,
            eventType: source == .mine ? StudyEventType.reviewMinePlay : StudyEventType.reviewTTSPlay,
            context: [
                "screen": "dictation_review",
                "unit": String(unitIndex + 1)
            ]
        )
        Task {
            let profile = DictationTimingProfile(
                mode: "review",
                passes: [DictationPlaybackPass(source: source, delayAfterSeconds: 0)]
            )
            await playbackEngine.playProfile(word: word, profile: profile) { _ in }
        }
    }

    private func hasMineRecording(for word: VocabularyEntry) -> Bool {
        guard let url = try? MinePronunciationStorage.fileURL(seedNumber: word.seedNumber),
              FileManager.default.fileExists(atPath: url.path),
              let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let n = attrs[.size] as? NSNumber else { return false }
        return n.uint64Value > 256
    }

    private var averageAccuracyValue: Int {
        let percentages = words.compactMap { historyPercent(for: $0) }
        guard !percentages.isEmpty else { return 0 }
        return Int((Double(percentages.reduce(0, +)) / Double(percentages.count)).rounded())
    }
}

// MARK: - Shared: errored attempts on vocab cards

/// Vocabulary card section: recent wrong dictation attempts for this lemma, one row per attempt,
/// including `DictationAttemptLog.errorType` (e.g. `spelling_mixed`) mapped for display.
struct ErroredAttemptsSection: View {
    let expectedLemma: String
    let wrongAttempts: [DictationAttemptLog]

    private static let displayLimit = 20

    /// Newest first so the latest mistake is on top.
    private var recentAttempts: [DictationAttemptLog] {
        wrongAttempts
            .sorted { $0.submittedAt > $1.submittedAt }
            .prefix(Self.displayLimit)
            .map { $0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeading("Errored attempts")
            if recentAttempts.isEmpty {
                Text("No spelling mistakes recorded yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(recentAttempts, id: \.id) { log in
                    attemptRow(log)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func sectionHeading(_ title: String) -> some View {
        Text(title)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func attemptRow(_ log: DictationAttemptLog) -> some View {
        let trimmed = log.userInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let display = trimmed.isEmpty ? "—" : trimmed
        let typeRaw = log.errorType?.trimmingCharacters(in: .whitespacesAndNewlines)

        return HStack(alignment: .center, spacing: 10) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.orange.opacity(0.85))
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(display)
                    .font(.caption.weight(.semibold))
                    .lineLimit(2)
                Text("Expected: \(expectedLemma)")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if let raw = typeRaw, !raw.isEmpty {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(DictationErrorKind.weaknessDisplayName(forStored: raw))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.orange)
                        Text("(\(raw))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .monospaced()
                    }
                } else {
                    Text("(no error type)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                Text(log.submittedAt, style: .relative)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: VocabularyEntry.self,
        SearchHistoryEntry.self,
        DictationWordStats.self,
        VocabularyStudyEvent.self,
        configurations: config
    )
    return NavigationStack {
        DictationReviewView(unitIndex: 0, words: [])
    }
    .modelContainer(container)
}
