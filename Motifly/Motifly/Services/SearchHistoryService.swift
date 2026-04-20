import Foundation
import SwiftData

enum SearchHistoryService {
    private static let maxEntries = 50

    static func recordSearch(modelContext: ModelContext, seedNumber: Int) {
        let sid = seedNumber
        let fd = FetchDescriptor<SearchHistoryEntry>(
            predicate: #Predicate<SearchHistoryEntry> { $0.seedNumber == sid }
        )
        if let existing = try? modelContext.fetch(fd).first {
            existing.searchedAt = Date()
        } else {
            modelContext.insert(SearchHistoryEntry(seedNumber: seedNumber, searchedAt: Date()))
        }

        trimToMax(modelContext: modelContext)
        try? modelContext.save()
    }

    private static func trimToMax(modelContext: ModelContext) {
        var fd = FetchDescriptor<SearchHistoryEntry>(
            sortBy: [SortDescriptor(\.searchedAt, order: .forward)]
        )
        guard let all = try? modelContext.fetch(fd), all.count > maxEntries else { return }
        let drop = all.count - maxEntries
        for i in 0..<drop {
            modelContext.delete(all[i])
        }
    }
}
