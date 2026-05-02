import SwiftData
import SwiftUI

struct DictationView: View {
    @Environment(\.modelContext) private var modelContext

    private struct DictationUnitGroup: Identifiable {
        let groupNumber: Int
        let words: [VocabularyEntry]

        var id: Int { groupNumber }
    }

    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var dictationProgress: DictationProgressStore
    @Query private var sessions: [DictationSession]
    /// Dictation units include all imported seed entries.
    @Query(sort: \VocabularyEntry.seedNumber)
    private var entries: [VocabularyEntry]

    private var unitGroups: [DictationUnitGroup] {
        guard !entries.isEmpty else { return [] }
        let grouped = Dictionary(grouping: entries) { groupNumber(for: $0) }
        return grouped
            .map { group, words in
                DictationUnitGroup(
                    groupNumber: group,
                    words: words.sorted { $0.seedNumber < $1.seedNumber }
                )
            }
            .sorted { $0.groupNumber < $1.groupNumber }
    }

    var body: some View {
        Group {
            if entries.isEmpty {
                ContentUnavailableView(
                    "No vocabulary",
                    systemImage: "tray",
                    description: Text("Import runs on first launch. Relaunch after install.")
                )
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        headerCard

                        LazyVStack(spacing: 14) {
                            ForEach(unitGroups) { unit in
                                unitCard(
                                    groupNumber: unit.groupNumber,
                                    wordsInUnit: unit.words
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
                .background(dictationScreenBackground)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var dictationScreenBackground: some View {
        Group {
            if colorScheme == .dark {
                Color(.systemGroupedBackground)
            } else {
                Color(red: 0.93, green: 0.95, blue: 0.98)
            }
        }
        .ignoresSafeArea()
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Dictation")
                .font(.title3.weight(.bold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .padding(.top, 8)
    }

    private func unitCard(groupNumber: Int, wordsInUnit: [VocabularyEntry]) -> some View {
        let unitIndex = max(0, groupNumber - 1)
        let badge = dictationProgress.badge(for: unitIndex)
        let low = ((groupNumber - 1) * 50) + 1
        let high = groupNumber * 50

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("Group \(groupNumber)")
                        .font(.caption.weight(.semibold))
                    Text("Words \(low)–\(high)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                lastDictationBadge(for: groupNumber)
            }

            HStack(alignment: .top, spacing: 6) {
                statPill(
                    title: "Accuracy",
                    value: accuracyText(for: badge)
                )
                reviewWordsPill(unitIndex: unitIndex, wordsInUnit: wordsInUnit)
                startDictationPill(unitIndex: unitIndex, wordsInUnit: wordsInUnit)
                wrongWordsFromLastSessionPill(
                    groupNumber: groupNumber,
                    unitIndex: unitIndex,
                    wordsInUnit: wordsInUnit
                )
            }

            lastFinishSummaryRow(groupNumber: groupNumber, wordsInUnit: wordsInUnit)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
        )
    }

    private func accuracyText(for badge: DictationUnitBadge) -> String {
        switch badge {
        case .started(let accuracy):
            return "\(accuracy)%"
        case .due, .new:
            return "—"
        }
    }

    private func lastDictationBadge(for unitIndex: Int) -> some View {
        let text = lastDictationText(for: unitIndex)
        return Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Capsule().fill(Color(.tertiarySystemFill)))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }

    private func lastDictationText(for groupNumber: Int) -> String {
        let unitScope = "unit_\(groupNumber)"
        let lastDate = sessions
            .filter { $0.sourceScope == unitScope }
            .compactMap { $0.endedAt ?? $0.startedAt }
            .max()
        guard let lastDate else { return "Never" }
        return "Last: \(relativeFormatter.localizedString(for: lastDate, relativeTo: .now))"
    }

    private func statPill(title: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.tertiarySystemGroupedBackground))
        )
    }

    private func startDictationPill(unitIndex: Int, wordsInUnit: [VocabularyEntry]) -> some View {
        NavigationLink {
            DictationSessionView(
                unitIndex: unitIndex,
                words: wordsInUnit,
                sessionSubset: .fullGroup
            )
        } label: {
            VStack(spacing: 2) {
                Text("Full")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text("session")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.blue)
            )
        }
        .buttonStyle(.plain)
    }

    /// Words missed in the latest **completed** dictation for this group (deduped, first-wrong order).
    private func wrongEntriesFromLastCompletedSession(groupNumber: Int, wordsInUnit: [VocabularyEntry]) -> [VocabularyEntry] {
        guard let session = lastCompletedSession(for: groupNumber) else { return [] }
        let sessionId = session.id
        let descriptor = FetchDescriptor<DictationAttemptLog>(
            predicate: #Predicate<DictationAttemptLog> { log in
                log.sessionId == sessionId && log.isCorrect == false
            },
            sortBy: [SortDescriptor(\.promptIndex, order: .forward)]
        )
        guard let logs = try? modelContext.fetch(descriptor) else { return [] }
        var seen = Set<Int>()
        var orderedSeeds: [Int] = []
        for log in logs {
            if !seen.contains(log.seedNumber) {
                seen.insert(log.seedNumber)
                orderedSeeds.append(log.seedNumber)
            }
        }
        let map = Dictionary(uniqueKeysWithValues: wordsInUnit.map { ($0.seedNumber, $0) })
        return orderedSeeds.compactMap { map[$0] }
    }

    private func wrongWordsFromLastSessionPill(
        groupNumber: Int,
        unitIndex: Int,
        wordsInUnit: [VocabularyEntry]
    ) -> some View {
        let wrongWords = wrongEntriesFromLastCompletedSession(groupNumber: groupNumber, wordsInUnit: wordsInUnit)
        return Group {
            if wrongWords.isEmpty {
                VStack(spacing: 2) {
                    Text("Wrong")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    Text("words")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(.tertiarySystemGroupedBackground))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color(.separator).opacity(0.35), lineWidth: 0.5)
                )
                .opacity(0.55)
                .accessibilityLabel("Wrong words from last session unavailable")
            } else {
                NavigationLink {
                    DictationSessionView(
                        unitIndex: unitIndex,
                        words: wrongWords,
                        sessionSubset: .lastWrongReview
                    )
                } label: {
                    VStack(spacing: 2) {
                        Text("Wrong")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.9))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                        Text("words")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.orange)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Dictation wrong words from last session, \(wrongWords.count) words")
            }
        }
    }

    /// Latest session with `status == "completed"` for this group (`unit_{groupNumber}`).
    private func lastCompletedSession(for groupNumber: Int) -> DictationSession? {
        let scope = "unit_\(groupNumber)"
        return sessions
            .filter { $0.sourceScope == scope && $0.status == "completed" }
            .max(by: { ($0.endedAt ?? $0.startedAt) < ($1.endedAt ?? $1.startedAt) })
    }

    private func lastFinishSummaryRow(groupNumber: Int, wordsInUnit: [VocabularyEntry]) -> some View {
        let hasSummary = lastCompletedSession(for: groupNumber) != nil
        return Group {
            if hasSummary {
                NavigationLink {
                    DictationPastSessionSummaryView(groupNumber: groupNumber, words: wordsInUnit)
                } label: {
                    lastFinishSummaryLabel()
                }
                .buttonStyle(.plain)
            } else {
                lastFinishSummaryLabel()
                    .opacity(0.42)
            }
        }
    }

    private func lastFinishSummaryLabel() -> some View {
        HStack(spacing: 8) {
            Image(systemName: "list.clipboard")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.blue)
            Text("Last finish summary")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.tertiarySystemGroupedBackground))
        )
    }

    private func reviewWordsPill(unitIndex: Int, wordsInUnit: [VocabularyEntry]) -> some View {
        NavigationLink {
            DictationReviewView(
                unitIndex: unitIndex,
                words: wordsInUnit
            )
        } label: {
            VStack(spacing: 2) {
                Text("Review")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text("Words")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(.tertiarySystemGroupedBackground))
            )
        }
        .buttonStyle(.plain)
    }

    private func groupNumber(for entry: VocabularyEntry) -> Int {
        if let assigned = entry.groupAssigned, assigned > 0 {
            return assigned
        }
        let rawNumber = rawSeedNumber(from: entry.seedNumber)
        return max(1, ((rawNumber - 1) / 50) + 1)
    }

    private func rawSeedNumber(from seedNumber: Int) -> Int {
        let base = seedNumber % 10_000_000
        return base > 0 ? base : seedNumber
    }

    private var relativeFormatter: RelativeDateTimeFormatter {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: VocabularyEntry.self,
        SearchHistoryEntry.self,
        DictationSession.self,
        DictationAttemptLog.self,
        configurations: config
    )
    return NavigationStack {
        DictationView()
    }
    .modelContainer(container)
    .environmentObject(DictationProgressStore())
}
