import SwiftData
import SwiftUI

struct DictationView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var dictationProgress: DictationProgressStore
    /// Dictation units use noun lemmas only (verbs use a separate card flow).
    @Query(
        filter: #Predicate<VocabularyEntry> { $0.entryKind == "noun" },
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
                                let wordCountInUnit = range.count

                                NavigationLink {
                                    DictationSessionView(
                                        unitIndex: unitIndex,
                                        words: Array(entries[range])
                                    )
                                } label: {
                                    unitCard(
                                        unitIndex: unitIndex,
                                        low: low,
                                        high: high,
                                        wordCountInUnit: wordCountInUnit
                                    )
                                }
                                .buttonStyle(.plain)
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
        VStack(alignment: .leading, spacing: 10) {
            Text("MOTIFLY")
                .font(.caption.weight(.semibold))
                .tracking(2)
                .foregroundStyle(.tertiary)

            Text("Dictation")
                .font(.title.bold())

            Text("Each unit contains 50 words. Tap a group to set dictation requirements.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .padding(.top, 8)
    }

    private func unitCard(unitIndex: Int, low: Int, high: Int, wordCountInUnit: Int) -> some View {
        let badge = dictationProgress.badge(for: unitIndex)

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Group \(unitIndex + 1)")
                        .font(.headline)
                    Text("Words \(low)–\(high)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                statusBadge(badge)
            }

            HStack(spacing: 12) {
                statPill(title: "Words", value: "\(wordCountInUnit)")
                statPill(
                    title: "Accuracy",
                    value: accuracyText(for: badge)
                )
            }
        }
        .padding(16)
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

    private func statusBadge(_ badge: DictationUnitBadge) -> some View {
        let colors: (Color, Color) = switch badge {
        case .started:
            (Color.green.opacity(0.18), Color.green.opacity(0.85))
        case .due:
            (Color.orange.opacity(0.2), Color.orange.opacity(0.95))
        case .new:
            (Color(.tertiarySystemFill), Color.secondary)
        }
        return Text(badge.title)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Capsule().fill(colors.0))
            .foregroundStyle(colors.1)
    }

    private func statPill(title: String, value: String) -> some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title2.weight(.bold))
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.tertiarySystemGroupedBackground))
        )
    }

    private func unitRange(unitIndex: Int) -> Range<Int> {
        let start = unitIndex * 50
        let end = min(start + 50, entries.count)
        return start..<end
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: VocabularyEntry.self,
        SearchHistoryEntry.self,
        configurations: config
    )
    return NavigationStack {
        DictationView()
    }
    .modelContainer(container)
    .environmentObject(DictationProgressStore())
}
