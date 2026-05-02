import SwiftData
import SwiftUI

/// Compact mastery summary that goes near the top of any word card.
///
/// Reads `DictationWordStats` for `seedNumber` and shows three short stats
/// from the V1 memory model (`french_dictation_memory_model.md`):
///   - Mastery percent
///   - Main weakness (or "On track" when no spelling-bucket counts yet)
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
        if let m = current?.overallMastery {
            return "\(Int(m.rounded()))%"
        }
        return "—"
    }

    private var weaknessText: String {
        guard let stats = current else { return "—" }
        if let key = stats.mainWeakness {
            return DictationErrorKind.weaknessDisplayName(forStored: key)
        }
        return "On track"
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
        HStack(spacing: 10) {
            chip(title: "Mastery", value: masteryText, tint: .blue)
            chip(title: "Weakness", value: weaknessText, tint: weaknessTint)
            chip(title: "Next review", value: nextReviewText, tint: .green)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var weaknessTint: Color {
        current?.mainWeakness == nil ? .green : .orange
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
