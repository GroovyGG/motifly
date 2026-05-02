import SwiftData
import SwiftUI

struct HomeView: View {
    private struct GroupProgressRow: Identifiable {
        let groupNumber: Int
        let dictated: Int
        let correct: Int
        let planned: Int

        var id: Int { groupNumber }
    }

    var isImportingVocabulary: Bool = false
    @AppStorage("motifly.settings.dailyGoalMinutes") private var dailyGoalMinutes = 30

    @Query(sort: \VocabularyStudyEvent.occurredAt, order: .reverse) private var studyEvents: [VocabularyStudyEvent]
    @Query(sort: \DictationAttemptLog.submittedAt, order: .reverse) private var attempts: [DictationAttemptLog]
    @Query private var sessions: [DictationSession]
    @Query private var wordStats: [DictationWordStats]
    @Query private var entries: [VocabularyEntry]

    private let weekDayLabels = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    private let weeklyGoalHours: Double = 5

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if isImportingVocabulary {
                    importBanner
                }

                topStatsCard
                studyLogCard
                groupProgressCard
                vocabularyProgressCard
                dailyGoalCard
                weeklyGoalCard
                debugTimelineLink
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Home")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    SettingsView()
                } label: {
                    Image(systemName: "gearshape")
                        .font(.title3)
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var importBanner: some View {
        HStack(alignment: .center, spacing: 10) {
            ProgressView()
            VStack(alignment: .leading, spacing: 3) {
                Text("Loading vocabulary")
                    .font(.subheadline.weight(.semibold))
                Text("First launch import is running in background.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private var topStatsCard: some View {
        HStack(spacing: 0) {
            statColumn(icon: "flame.fill", value: "\(studyStreakDays)", unit: "day streak", subtitle: "Keep it up!")
            Divider()
            statColumn(icon: "clock", value: weeklyHoursText, unit: "study time this week", subtitle: weeklyDeltaText)
            Divider()
            statColumn(icon: "scope", value: "\(weeklyAccuracyPercent)%", unit: "avg accuracy", subtitle: "This week")
        }
        .cardStyle()
    }

    private func statColumn(icon: String, value: String, unit: String, subtitle: String) -> some View {
        VStack(spacing: 2) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(.blue)
            Text(value)
                .font(.title3.weight(.semibold))
            Text(unit)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }

    private var studyLogCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Study Log")
                    .font(.headline)
                Spacer()
                Text("Last 6 Months")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.blue)
            }

            heatmapView

            HStack {
                Text("Less")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                ForEach(0..<5, id: \.self) { level in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(heatColor(level: level))
                        .frame(width: 12, height: 8)
                }
                Text("More")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Daily study intensity")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .cardStyle()
    }

    private var heatmapView: some View {
        let columns = heatmapColumns
        return HStack(alignment: .top, spacing: 6) {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(weekDayLabels, id: \.self) { label in
                    Text(label)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(height: 12)
                }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 3) {
                    ForEach(columns.indices, id: \.self) { col in
                        VStack(spacing: 3) {
                            ForEach(0..<7, id: \.self) { row in
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(heatColor(level: columns[col][row]))
                                    .frame(width: 10, height: 10)
                            }
                        }
                    }
                }
            }
        }
    }

    private var groupProgressCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Group Progress")
                    .font(.headline)
                Spacer()
                Text("Dictated")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("·")
                    .foregroundStyle(.secondary)
                Text("Correct")
                    .font(.caption2)
                    .foregroundStyle(.blue)
            }
            ForEach(groupProgressRows.prefix(5)) { row in
                HStack(spacing: 8) {
                    Image(systemName: "square.stack.3d.up.fill")
                        .font(.caption)
                        .foregroundStyle(.blue)
                    Text("Group \(row.groupNumber)")
                        .font(.subheadline)
                        .frame(width: 62, alignment: .leading)
                    VStack(spacing: 5) {
                        ProgressView(value: Double(row.dictated), total: Double(max(1, row.planned)))
                            .tint(Color.blue.opacity(0.35))
                        ProgressView(value: Double(row.correct), total: Double(max(1, row.planned)))
                            .tint(.blue)
                    }
                    .frame(maxWidth: .infinity)
                    Text("\(row.dictated)/\(row.planned)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(row.correct)/\(row.planned)")
                        .font(.caption)
                        .foregroundStyle(.primary)
                }
            }
        }
        .cardStyle()
    }

    private var vocabularyProgressCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Vocabulary Progress")
                .font(.headline)
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .stroke(Color.blue.opacity(0.15), lineWidth: 8)
                        .frame(width: 74, height: 74)
                    Circle()
                        .trim(from: 0, to: progressGoalRatio)
                        .stroke(Color.blue, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 74, height: 74)
                    VStack(spacing: 0) {
                        Text("\(Int(progressGoalRatio * 100))%")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.blue)
                        Text("of goal")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    metricLine(title: "Dictated", value: "\(dictatedWordsCount)/\(goalWordsCount)", ratio: dictatedWordsRatio)
                    metricLine(title: "Correct", value: "\(correctWordsCount)/\(goalWordsCount)", ratio: correctWordsRatio)
                    Text("Goal: \(goalWordsCount) words")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .cardStyle()
    }

    private func metricLine(title: String, value: String, ratio: Double) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(title)
                    .font(.caption)
                Spacer()
                Text(value)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: ratio)
                .tint(.blue)
        }
    }

    private var weeklyGoalCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "target")
                    .foregroundStyle(.blue)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Weekly Goal")
                        .font(.subheadline.weight(.semibold))
                    Text("Study \(Int(weeklyGoalHours)) hours this week")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(String(format: "%.1f", weeklyHours)) / \(Int(weeklyGoalHours)) h")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.blue)
            }
            ProgressView(value: weeklyHours, total: weeklyGoalHours)
                .tint(.blue)
        }
        .cardStyle()
    }

    private var dailyGoalCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "sun.max")
                    .foregroundStyle(.blue)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Daily Goal")
                        .font(.subheadline.weight(.semibold))
                    Text("Study \(dailyGoalMinutes) minutes today")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(String(format: "%.1f", todayHours)) / \(String(format: "%.1f", dailyGoalHours)) h")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.blue)
            }
            ProgressView(value: todayHours, total: dailyGoalHours)
                .tint(.blue)
        }
        .cardStyle()
    }

    private var debugTimelineLink: some View {
        NavigationLink {
            DebugStudyTimelineView()
        } label: {
            Label("Debug Study Timeline", systemImage: "clock.arrow.circlepath")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    // MARK: - Metrics

    private var weeklyAttempts: [DictationAttemptLog] {
        let cal = Calendar.current
        let start = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())) ?? .distantPast
        return attempts.filter { $0.submittedAt >= start }
    }

    private var todayAttempts: [DictationAttemptLog] {
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        return attempts.filter { $0.submittedAt >= start }
    }

    private var weeklyHours: Double {
        Double(weeklyAttempts.reduce(0) { $0 + max(0, $1.elapsedMs) }) / 3_600_000.0
    }

    private var todayHours: Double {
        Double(todayAttempts.reduce(0) { $0 + max(0, $1.elapsedMs) }) / 3_600_000.0
    }

    private var dailyGoalHours: Double {
        max(1.0 / 60.0, Double(dailyGoalMinutes) / 60.0)
    }

    private var weeklyHoursText: String {
        let h = Int(weeklyHours)
        let m = Int((weeklyHours - Double(h)) * 60.0)
        return "\(h) h \(m) m"
    }

    private var weeklyAccuracyPercent: Int {
        guard !weeklyAttempts.isEmpty else { return 0 }
        let correct = weeklyAttempts.reduce(0) { $0 + ($1.isCorrect ? 1 : 0) }
        return Int((Double(correct) / Double(weeklyAttempts.count) * 100).rounded())
    }

    private var weeklyDeltaText: String {
        let cal = Calendar.current
        let thisWeekStart = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())) ?? .distantPast
        let lastWeekStart = cal.date(byAdding: .day, value: -7, to: thisWeekStart) ?? .distantPast
        let lastWeekEnd = thisWeekStart
        let lastWeekAttempts = attempts.filter { $0.submittedAt >= lastWeekStart && $0.submittedAt < lastWeekEnd }
        let lastWeekHours = Double(lastWeekAttempts.reduce(0) { $0 + max(0, $1.elapsedMs) }) / 3_600_000.0
        let diff = weeklyHours - lastWeekHours
        let sign = diff >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.1f", diff)) h vs last week"
    }

    /// Days with any logged activity: timeline events **or** dictation attempts (attempts alone drive the heatmap when study events were never written).
    private var activeStudyDays: Set<Date> {
        let cal = Calendar.current
        let fromAttempts = Set(attempts.map { cal.startOfDay(for: $0.submittedAt) })
        let fromEvents = Set(studyEvents.map { cal.startOfDay(for: $0.occurredAt) })
        return fromAttempts.union(fromEvents)
    }

    /// Per-day intensity for the heatmap: `max(attempts, studyEvents)` so dictation practice counts even without `VocabularyStudyEvent`, without double-counting each submit twice when both exist.
    private var heatmapDayCounts: [Date: Int] {
        let cal = Calendar.current
        let attemptCounts = Dictionary(grouping: attempts.map { cal.startOfDay(for: $0.submittedAt) }) { $0 }.mapValues(\.count)
        let eventCounts = Dictionary(grouping: studyEvents.map { cal.startOfDay(for: $0.occurredAt) }) { $0 }.mapValues(\.count)
        let allKeys = Set(attemptCounts.keys).union(eventCounts.keys)
        var merged: [Date: Int] = [:]
        for d in allKeys {
            merged[d] = max(attemptCounts[d] ?? 0, eventCounts[d] ?? 0)
        }
        return merged
    }

    private var studyStreakDays: Int {
        let cal = Calendar.current
        let days = activeStudyDays
        var count = 0
        var cursor = cal.startOfDay(for: Date())
        while days.contains(cursor) {
            count += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
        }
        return count
    }

    private var heatmapColumns: [[Int]] {
        let cal = Calendar.current
        let now = Date()
        guard let startRaw = cal.date(byAdding: .day, value: -181, to: now) else { return [] }
        let start = cal.startOfDay(for: startRaw)
        let dayCounts = heatmapDayCounts
        let maxCount = max(1, dayCounts.values.max() ?? 1)
        var columns: [[Int]] = []
        var cursor = start
        while cursor <= now {
            var week: [Int] = Array(repeating: 0, count: 7)
            for i in 0..<7 {
                guard let day = cal.date(byAdding: .day, value: i, to: cursor) else { continue }
                let normalized = cal.startOfDay(for: day)
                let c = dayCounts[normalized] ?? 0
                let level = Int((Double(c) / Double(maxCount) * 4.0).rounded())
                let weekday = (cal.component(.weekday, from: day) + 5) % 7 // Mon=0
                week[weekday] = level
            }
            columns.append(week)
            guard let nextWeek = cal.date(byAdding: .day, value: 7, to: cursor) else { break }
            cursor = nextWeek
        }
        return columns
    }

    private func heatColor(level: Int) -> Color {
        switch max(0, min(level, 4)) {
        case 0: return Color.blue.opacity(0.08)
        case 1: return Color.blue.opacity(0.22)
        case 2: return Color.blue.opacity(0.4)
        case 3: return Color.blue.opacity(0.62)
        default: return Color.blue
        }
    }

    private var groupProgressRows: [GroupProgressRow] {
        let completed = sessions.filter { $0.status == "completed" }
        let grouped = Dictionary(grouping: completed) { session in
            parseGroupNumber(from: session.sourceScope)
        }
        return grouped.compactMap { groupNumber, sessions in
            guard groupNumber > 0 else { return nil }
            let latest = sessions.max { ($0.endedAt ?? $0.startedAt) < ($1.endedAt ?? $1.startedAt) }
            guard let latest else { return nil }
            return GroupProgressRow(
                groupNumber: groupNumber,
                dictated: latest.attemptedCount,
                correct: latest.correctCount,
                planned: max(1, latest.plannedCount)
            )
        }
        .sorted { $0.groupNumber < $1.groupNumber }
    }

    private func parseGroupNumber(from scope: String) -> Int {
        guard scope.hasPrefix("unit_") else { return 0 }
        return Int(scope.replacingOccurrences(of: "unit_", with: "")) ?? 0
    }

    private var goalWordsCount: Int {
        max(1, entries.count)
    }

    private var dictatedWordsCount: Int {
        wordStats.filter { $0.attemptCount > 0 }.count
    }

    private var correctWordsCount: Int {
        wordStats.filter { $0.correctCount > 0 }.count
    }

    private var progressGoalRatio: Double {
        min(1, Double(dictatedWordsCount) / Double(goalWordsCount))
    }

    private var dictatedWordsRatio: Double {
        min(1, Double(dictatedWordsCount) / Double(goalWordsCount))
    }

    private var correctWordsRatio: Double {
        min(1, Double(correctWordsCount) / Double(goalWordsCount))
    }
}

private extension View {
    func cardStyle() -> some View {
        self
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: VocabularyEntry.self,
        SearchHistoryEntry.self,
        DictationSession.self,
        DictationAttemptLog.self,
        DictationWordStats.self,
        VocabularyStudyEvent.self,
        configurations: config
    )
    return NavigationStack { HomeView() }
        .modelContainer(container)
}
