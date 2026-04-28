import SwiftData
import SwiftUI

struct DictationView: View {
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
                .font(.title.bold())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
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

            HStack(spacing: 12) {
                statPill(
                    title: "Accuracy",
                    value: accuracyText(for: badge)
                )
                reviewWordsPill(unitIndex: unitIndex, wordsInUnit: wordsInUnit)
                startDictationPill(unitIndex: unitIndex, wordsInUnit: wordsInUnit)
            }
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
        VStack(spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.tertiarySystemGroupedBackground))
        )
    }

    private func startDictationPill(unitIndex: Int, wordsInUnit: [VocabularyEntry]) -> some View {
        NavigationLink {
            DictationSessionView(
                unitIndex: unitIndex,
                words: wordsInUnit
            )
        } label: {
            VStack(spacing: 4) {
                Text("Start")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.9))
                Text("Dictation")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.blue)
            )
        }
        .buttonStyle(.plain)
    }

    private func reviewWordsPill(unitIndex: Int, wordsInUnit: [VocabularyEntry]) -> some View {
        NavigationLink {
            DictationReviewView(
                unitIndex: unitIndex,
                words: wordsInUnit
            )
        } label: {
            VStack(spacing: 4) {
                Text("Review")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("Words")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
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
        configurations: config
    )
    return NavigationStack {
        DictationView()
    }
    .modelContainer(container)
    .environmentObject(DictationProgressStore())
}
