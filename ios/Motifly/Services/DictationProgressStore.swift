import Combine
import Foundation

/// Persists per-unit dictation status for the list UI (UserDefaults).
final class DictationProgressStore: ObservableObject {
    private let defaultsKey = "motifly.dictation.unitRecords.v1"

    struct UnitRecord: Codable, Equatable {
        var lastAccuracyPercent: Int?
        /// True when the user left a session before finishing (shows "Due").
        var isAbandoned: Bool = false
    }

    @Published private(set) var records: [Int: UnitRecord] = [:]

    init() {
        load()
    }

    func record(for unitIndex: Int) -> UnitRecord {
        records[unitIndex] ?? UnitRecord()
    }

    func completeSession(unitIndex: Int, correct: Int, total: Int) {
        guard total > 0 else { return }
        let pct = min(100, max(0, Int((Double(correct) / Double(total) * 100).rounded())))
        var r = records[unitIndex] ?? UnitRecord()
        r.lastAccuracyPercent = pct
        r.isAbandoned = false
        records[unitIndex] = r
        save()
    }

    /// Marks a unit as "Due" only when the learner leaves before any completed session (no score yet).
    func abandonSession(unitIndex: Int) {
        var r = records[unitIndex] ?? UnitRecord()
        guard r.lastAccuracyPercent == nil else { return }
        r.isAbandoned = true
        records[unitIndex] = r
        save()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey) else { return }
        let decoded = try? JSONDecoder().decode([String: UnitRecord].self, from: data)
        var map: [Int: UnitRecord] = [:]
        decoded?.forEach { key, value in
            if let i = Int(key) { map[i] = value }
        }
        records = map
    }

    private func save() {
        var stringKeyed: [String: UnitRecord] = [:]
        records.forEach { stringKeyed[String($0.key)] = $0.value }
        if let data = try? JSONEncoder().encode(stringKeyed) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }
    }
}

enum DictationUnitBadge: Equatable {
    case new
    case due
    case started(accuracy: Int)

    var title: String {
        switch self {
        case .new: "New"
        case .due: "Due"
        case .started: "Started"
        }
    }
}

extension DictationProgressStore {
    func badge(for unitIndex: Int) -> DictationUnitBadge {
        let r = record(for: unitIndex)
        if r.isAbandoned { return .due }
        if let acc = r.lastAccuracyPercent { return .started(accuracy: acc) }
        return .new
    }
}
