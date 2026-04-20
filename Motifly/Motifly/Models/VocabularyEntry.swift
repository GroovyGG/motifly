import Foundation
import SwiftData

@Model
final class VocabularyEntry {
    @Attribute(.unique) var seedNumber: Int
    var frenchLemma: String
    var english: String
    var pos: String
    var thematic: String
    var exampleFrench: String
    var exampleEnglish: String

    init(
        seedNumber: Int,
        frenchLemma: String,
        english: String,
        pos: String,
        thematic: String,
        exampleFrench: String,
        exampleEnglish: String
    ) {
        self.seedNumber = seedNumber
        self.frenchLemma = frenchLemma
        self.english = english
        self.pos = pos
        self.thematic = thematic
        self.exampleFrench = exampleFrench
        self.exampleEnglish = exampleEnglish
    }
}
