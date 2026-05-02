import SwiftData
import SwiftUI

/// Compact mastery summary that goes near the top of any word card.
///
/// Reads `DictationWordStats` for `seedNumber` and shows three short stats
/// from the V1 memory model (`docs/french_dictation_memory_model.md`):
///   - Mastery percent (`overallMastery` when set; else lifetime accuracy from attempts)
///   - Main weakness (dominant spelling subtype, or a neutral label plus a detail line below)
///   - Next review date
struct WordMasteryHeader: View {
    let seedNumber: Int
    @Query private var stats: [DictationWordStats]

    init(seedNumber: Int) {
        self.seedNumber = seedNumber
        let sid = seedNumber
        _stats = Query(filter: #Predicate<DictationWordStats> { $0.seedNumber == sid })
    }

    private var current: DictationWordStats? { stats.first }

    private var masteryText: String {
        guard let stats = current else { return "—" }
        if let m = stats.overallMastery {
            return "\(Int(m.rounded()))%"
        }
        // Legacy rows or any install where stats exist before `overallMastery` was written:
        // still show something useful from lifetime dictation counts.
        if stats.attemptCount > 0 {
            let p = Int((Double(stats.correctCount) / Double(stats.attemptCount) * 100.0).rounded())
            return "\(p)%"
        }
        return "—"
    }

    /// Primary label in the Weakness chip (never the vague "On track").
    private var weaknessText: String {
        guard let stats = current else { return "—" }
        if let key = stats.mainWeakness {
            return DictationErrorKind.weaknessDisplayName(forStored: key)
        }
        if stats.attemptCount == 0 {
            return "—"
        }
        return "No dominant type"
    }

    /// Extra context under the three chips when weakness is not a single spelling subtype.
    private var supplementLine: String? {
        guard let stats = current else { return nil }
        if stats.mainWeakness != nil { return nil }

        if stats.attemptCount == 0 {
            return "Dictation stats appear after you submit answers in a session."
        }

        var parts: [String] = []
        if let d = stats.dictationScore {
            parts.append("Recent dictation \(Int(d.rounded()))%")
        }
        if let sp = stats.spellingScore {
            parts.append("spelling \(Int(sp.rounded()))%")
        }
        if let li = stats.listeningScore {
            parts.append("listening \(Int(li.rounded()))%")
        }
        if let me = stats.meaningScore {
            parts.append("meaning \(Int(me.rounded()))%")
        }
        if !parts.isEmpty {
            return parts.joined(separator: " · ") + " (last \(WordMasteryUpdater.recentWindow) attempts)."
        }

        let life = Int((Double(stats.correctCount) / Double(max(1, stats.attemptCount)) * 100.0).rounded())
        return "\(stats.attemptCount) dictation attempts, lifetime \(life)% correct — no recurring spelling subtype logged yet."
    }

    private var nextReviewText: String {
        guard let date = current?.nextReviewDate else { return "—" }
        let cal = Calendar.current
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: .now), to: cal.startOfDay(for: date)).day ?? 0
        switch days {
        case ..<0: return "Overdue"
        case 0: return "Today"
        case 1: return "Tomorrow"
        default: return "In \(days)d"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                chip(title: "Mastery", value: masteryText, tint: .blue)
                chip(title: "Weakness", value: weaknessText, tint: weaknessTint)
                chip(title: "Next review", value: nextReviewText, tint: .green)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let line = supplementLine {
                Text(line)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var weaknessTint: Color {
        guard let s = current else { return Color.secondary }
        return s.mainWeakness == nil ? Color.secondary : Color.orange
    }

    private func chip(title: String, value: String, tint: Color) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.tertiarySystemGroupedBackground))
        )
    }
}
