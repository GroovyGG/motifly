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

    /// Chinese gloss from `seed_nouns.csv` (`chinese_explanation`). Optional for store migration.
    var chineseExplanation: String?
    /// Single-letter or short code from CSV `gender` (e.g. m, f).
    var genderCode: String?
    var lemmaArticle: String?
    var pluralForm: String?
    var pluralType: String?

    init(
        seedNumber: Int,
        frenchLemma: String,
        english: String,
        pos: String,
        thematic: String,
        exampleFrench: String,
        exampleEnglish: String,
        chineseExplanation: String? = nil,
        genderCode: String? = nil,
        lemmaArticle: String? = nil,
        pluralForm: String? = nil,
        pluralType: String? = nil
    ) {
        self.seedNumber = seedNumber
        self.frenchLemma = frenchLemma
        self.english = english
        self.pos = pos
        self.thematic = thematic
        self.exampleFrench = exampleFrench
        self.exampleEnglish = exampleEnglish
        self.chineseExplanation = chineseExplanation
        self.genderCode = genderCode
        self.lemmaArticle = lemmaArticle
        self.pluralForm = pluralForm
        self.pluralType = pluralType
    }
}
