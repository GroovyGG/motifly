import SwiftUI

/// One grouped wrong spelling: same normalized typed input aggregated across attempts.
struct DictationMistakeAggregation: Identifiable {
    /// Stable grouping key (`normalizedInput`).
    let id: String
    let displayUserInput: String
    let count: Int
    let lastSubmittedAt: Date
}

private enum DictationMistakeAggregationBuilder {
    static func topAggregatedMistakes(from wrongAttempts: [DictationAttemptLog], limit: Int) -> [DictationMistakeAggregation] {
        guard !wrongAttempts.isEmpty else { return [] }

        struct Bucket {
            var count: Int
            var displayUserInput: String
            var lastSubmittedAt: Date
        }

        var buckets: [String: Bucket] = [:]

        for log in wrongAttempts {
            let key = log.normalizedInput
            let trimmedDisplay = log.userInput.trimmingCharacters(in: .whitespacesAndNewlines)
            let display = trimmedDisplay.isEmpty ? "—" : trimmedDisplay

            if var existing = buckets[key] {
                existing.count += 1
                if log.submittedAt >= existing.lastSubmittedAt {
                    existing.lastSubmittedAt = log.submittedAt
                    existing.displayUserInput = display
                }
                buckets[key] = existing
            } else {
                buckets[key] = Bucket(count: 1, displayUserInput: display, lastSubmittedAt: log.submittedAt)
            }
        }

        let ranked = buckets
            .map { key, b in
                DictationMistakeAggregation(
                    id: key.isEmpty ? "__normalized_empty__" : key,
                    displayUserInput: b.displayUserInput,
                    count: b.count,
                    lastSubmittedAt: b.lastSubmittedAt
                )
            }
            .sorted { lhs, rhs in
                if lhs.count != rhs.count { return lhs.count > rhs.count }
                return lhs.lastSubmittedAt > rhs.lastSubmittedAt
            }
        return Array(ranked.prefix(limit))
    }
}

/// Vocabulary card section: most common wrong inputs for this word (aligned with review row styling).
struct ErroredAttemptsSection: View {
    let expectedLemma: String
    let wrongAttempts: [DictationAttemptLog]

    private var rows: [DictationMistakeAggregation] {
        DictationMistakeAggregationBuilder.topAggregatedMistakes(from: wrongAttempts, limit: 5)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeading("Errored attempts")
            if rows.isEmpty {
                Text("No spelling mistakes recorded yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(rows) { row in
                    mistakeRow(row)
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

    private func mistakeRow(_ row: DictationMistakeAggregation) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Text("\(row.count)×")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.blue)
                .frame(width: 30, height: 30)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.blue.opacity(0.08))
                )

            VStack(alignment: .leading, spacing: 1) {
                Text(row.displayUserInput)
                    .font(.caption.weight(.semibold))
                    .lineLimit(2)
                Text("Expected: \(expectedLemma)")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(row.lastSubmittedAt, style: .relative)
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
