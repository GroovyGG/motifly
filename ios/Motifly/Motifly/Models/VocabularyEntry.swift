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

    /// `noun` or `verb`; `nil` treated as noun (legacy rows before this field).
    var entryKind: String?

    /// Chinese gloss from `seed_nouns.csv` / `seed_verbs.csv` (`chinese_explanation`). Optional for store migration.
    var chineseExplanation: String?
    /// Single-letter or short code from CSV `gender` (e.g. m, f). Nouns only.
    var genderCode: String?
    var lemmaArticle: String?
    var pluralForm: String?
    var pluralType: String?

    // MARK: - Verb-only (nil for nouns)

    var verbGroup: String?
    var verbAuxiliary: String?
    var verbPastParticiple: String?
    /// JSON array of `{ "person": "je", "form": "suis" }` for present tense.
    var verbPresentJSON: String?
    /// JSON array for passé composé.
    var verbPasseComposeJSON: String?

    init(
        seedNumber: Int,
        frenchLemma: String,
        english: String,
        pos: String,
        thematic: String,
        exampleFrench: String,
        exampleEnglish: String,
        entryKind: String? = "noun",
        chineseExplanation: String? = nil,
        genderCode: String? = nil,
        lemmaArticle: String? = nil,
        pluralForm: String? = nil,
        pluralType: String? = nil,
        verbGroup: String? = nil,
        verbAuxiliary: String? = nil,
        verbPastParticiple: String? = nil,
        verbPresentJSON: String? = nil,
        verbPasseComposeJSON: String? = nil
    ) {
        self.seedNumber = seedNumber
        self.frenchLemma = frenchLemma
        self.english = english
        self.pos = pos
        self.thematic = thematic
        self.exampleFrench = exampleFrench
        self.exampleEnglish = exampleEnglish
        self.entryKind = entryKind
        self.chineseExplanation = chineseExplanation
        self.genderCode = genderCode
        self.lemmaArticle = lemmaArticle
        self.pluralForm = pluralForm
        self.pluralType = pluralType
        self.verbGroup = verbGroup
        self.verbAuxiliary = verbAuxiliary
        self.verbPastParticiple = verbPastParticiple
        self.verbPresentJSON = verbPresentJSON
        self.verbPasseComposeJSON = verbPasseComposeJSON
    }
}
