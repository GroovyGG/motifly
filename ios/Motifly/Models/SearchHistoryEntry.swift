import Foundation
import SwiftData

/// One row per distinct word ever searched; `searchedAt` is last time user picked this word from search.
@Model
final class SearchHistoryEntry {
    @Attribute(.unique) var seedNumber: Int
    var searchedAt: Date

    init(seedNumber: Int, searchedAt: Date = .now) {
        self.seedNumber = seedNumber
        self.searchedAt = searchedAt
    }
}
