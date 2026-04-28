import SwiftData
import SwiftUI

struct DictationView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var dictationProgress: DictationProgressStore
    @Query private var sessions: [DictationSession]
    /// Dictation units use noun lemmas only (verbs/adjectives use vocabulary cards).
    @Query(
        filter: #Predicate<VocabularyEntry> { $0.entryKind == nil || $0.entryKind == "noun" },
        sort: \VocabularyEntry.seedNumber
    )
    private var entries: [VocabularyEntry]

    private var unitCount: Int {
        guard !entries.isEmpty else { return 0 }
        return (entries.count + 49) / 50
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
                            ForEach(0..<unitCount, id: \.self) { unitIndex in
                                let range = unitRange(unitIndex: unitIndex)
                                let low = entries[range.lowerBound].seedNumber
                                let high = entries[range.upperBound - 1].seedNumber
                                unitCard(
                                    unitIndex: unitIndex,
                                    low: low,
                                    high: high,
                                    wordsInUnit: Array(entries[range])
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

    private func unitCard(unitIndex: Int, low: Int, high: Int, wordsInUnit: [VocabularyEntry]) -> some View {
        let badge = dictationProgress.badge(for: unitIndex)

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("Group \(unitIndex + 1)")
                        .font(.caption.weight(.semibold))
                    Text("Words \(low)–\(high)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                lastDictationBadge(for: unitIndex)
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

    private func lastDictationText(for unitIndex: Int) -> String {
        let unitScope = "unit_\(unitIndex + 1)"
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
            DictationSessionView(
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

    private func unitRange(unitIndex: Int) -> Range<Int> {
        let start = unitIndex * 50
        let end = min(start + 50, entries.count)
        return start..<end
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
