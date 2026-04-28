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

    /// `noun`, `verb`, `adjective`, `adverb`, `determiner`, `pronoun`, or `preposition`; `nil` treated as noun (legacy rows before this field).
    var entryKind: String?

    /// Chinese gloss from seed CSVs. Optional for store migration.
    var chineseExplanation: String?
    /// Single-letter or short code from CSV `gender` (e.g. m, f). Nouns only.
    var genderCode: String?
    var lemmaArticle: String?
    var pluralForm: String?
    var pluralType: String?

    // MARK: - Verb-only (nil for other kinds)

    var verbGroup: String?
    var verbAuxiliary: String?
    var verbPastParticiple: String?
    /// JSON array of `{ "person": "je", "form": "suis" }` for present tense.
    var verbPresentJSON: String?
    /// JSON array for passé composé.
    var verbPasseComposeJSON: String?

    // MARK: - Adjective-only

    var adjMascSingular: String?
    var adjFemSingular: String?
    var adjMascPlural: String?
    var adjFemPlural: String?
    var adjAdjectiveType: String?
    /// From CSV `is_invariable`; ignored for non-adjectives. Optional so existing stores migrate without a default for old rows.
    var adjInvariable: Bool?
    /// Short teaching line from seed (`memory_note`).
    var adjMemoryNote: String?
    /// Form to emphasize in the example sentence when present (`example_target_form`).
    var adjExampleTargetForm: String?

    // MARK: - Adverb-only

    /// e.g. manner, time, negation (`adverb_type` in seed_adv.csv).
    var advAdverbType: String?
    /// Formation description (`formation`).
    var advFormation: String?
    var advIsInvariable: Bool?
    /// Short placement code (`placement_position`).
    var advPlacementPosition: String?
    /// Longer placement explanation (`placement_note`).
    var advPlacementNote: String?
    /// Example fragment (`placement_example_front`).
    var advPlacementExampleFront: String?
    /// Example fragment (`placement_example_end`).
    var advPlacementExampleEnd: String?
    /// Teaching line from seed (`memory_note` for adverbs).
    var advMemoryNote: String?
    /// Highlight token in example (`example_target_form`).
    var advExampleTargetForm: String?

    // MARK: - Determiner-only

    /// e.g. demonstrative determiner, definite article (`determiner_type` in seed_determiners.csv).
    var detDeterminerType: String?
    /// Longer usage line (`usage_note`).
    var detUsageNote: String?
    var detMascSingular: String?
    var detFemSingular: String?
    var detMascPlural: String?
    var detFemPlural: String?
    /// One or more patterns; use `|` in CSV to split into separate lines in the UI (`noun_pattern`).
    var detNounPatternsRaw: String?
    /// Token to emphasize in the example sentence (`example_target_form`).
    var detExampleTargetForm: String?

    // MARK: - Pronoun-only (`seed_pronouns.csv`)

    var proPronounType: String?
    var proIsFunctionWord: Bool?
    var proPerson: String?
    var proNumberFeature: String?
    var proGenderFeature: String?
    var proReplacesWhat: String?
    var proPositionNote: String?
    /// `position_examples` in CSV; use `|` to split lines in UI.
    var proPositionExamplesRaw: String?
    var proUsageNote: String?
    var proMemoryNote: String?
    var proExampleTargetForm: String?

    // MARK: - Preposition-only (`seed_prepositions.csv`)

    var prepPrepositionType: String?
    var prepIsFunctionWord: Bool?
    /// Short gloss from CSV `core_meaning`.
    var prepCoreMeaning: String?
    var prepPattern1: String?
    var prepPattern2: String?
    var prepPattern3: String?
    /// Pipe-separated phrases (`common_collocations` in CSV).
    var prepCommonCollocationsRaw: String?
    var prepUsageNote: String?
    /// Teaching line from seed (`memory_note`).
    var prepMemoryNote: String?
    var prepExampleTargetForm: String?

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
        verbPasseComposeJSON: String? = nil,
        adjMascSingular: String? = nil,
        adjFemSingular: String? = nil,
        adjMascPlural: String? = nil,
        adjFemPlural: String? = nil,
        adjAdjectiveType: String? = nil,
        adjInvariable: Bool? = nil,
        adjMemoryNote: String? = nil,
        adjExampleTargetForm: String? = nil,
        advAdverbType: String? = nil,
        advFormation: String? = nil,
        advIsInvariable: Bool? = nil,
        advPlacementPosition: String? = nil,
        advPlacementNote: String? = nil,
        advPlacementExampleFront: String? = nil,
        advPlacementExampleEnd: String? = nil,
        advMemoryNote: String? = nil,
        advExampleTargetForm: String? = nil,
        detDeterminerType: String? = nil,
        detUsageNote: String? = nil,
        detMascSingular: String? = nil,
        detFemSingular: String? = nil,
        detMascPlural: String? = nil,
        detFemPlural: String? = nil,
        detNounPatternsRaw: String? = nil,
        detExampleTargetForm: String? = nil,
        proPronounType: String? = nil,
        proIsFunctionWord: Bool? = nil,
        proPerson: String? = nil,
        proNumberFeature: String? = nil,
        proGenderFeature: String? = nil,
        proReplacesWhat: String? = nil,
        proPositionNote: String? = nil,
        proPositionExamplesRaw: String? = nil,
        proUsageNote: String? = nil,
        proMemoryNote: String? = nil,
        proExampleTargetForm: String? = nil,
        prepPrepositionType: String? = nil,
        prepIsFunctionWord: Bool? = nil,
        prepCoreMeaning: String? = nil,
        prepPattern1: String? = nil,
        prepPattern2: String? = nil,
        prepPattern3: String? = nil,
        prepCommonCollocationsRaw: String? = nil,
        prepUsageNote: String? = nil,
        prepMemoryNote: String? = nil,
        prepExampleTargetForm: String? = nil
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
        self.adjMascSingular = adjMascSingular
        self.adjFemSingular = adjFemSingular
        self.adjMascPlural = adjMascPlural
        self.adjFemPlural = adjFemPlural
        self.adjAdjectiveType = adjAdjectiveType
        self.adjInvariable = adjInvariable
        self.adjMemoryNote = adjMemoryNote
        self.adjExampleTargetForm = adjExampleTargetForm
        self.advAdverbType = advAdverbType
        self.advFormation = advFormation
        self.advIsInvariable = advIsInvariable
        self.advPlacementPosition = advPlacementPosition
        self.advPlacementNote = advPlacementNote
        self.advPlacementExampleFront = advPlacementExampleFront
        self.advPlacementExampleEnd = advPlacementExampleEnd
        self.advMemoryNote = advMemoryNote
        self.advExampleTargetForm = advExampleTargetForm
        self.detDeterminerType = detDeterminerType
        self.detUsageNote = detUsageNote
        self.detMascSingular = detMascSingular
        self.detFemSingular = detFemSingular
        self.detMascPlural = detMascPlural
        self.detFemPlural = detFemPlural
        self.detNounPatternsRaw = detNounPatternsRaw
        self.detExampleTargetForm = detExampleTargetForm
        self.proPronounType = proPronounType
        self.proIsFunctionWord = proIsFunctionWord
        self.proPerson = proPerson
        self.proNumberFeature = proNumberFeature
        self.proGenderFeature = proGenderFeature
        self.proReplacesWhat = proReplacesWhat
        self.proPositionNote = proPositionNote
        self.proPositionExamplesRaw = proPositionExamplesRaw
        self.proUsageNote = proUsageNote
        self.proMemoryNote = proMemoryNote
        self.proExampleTargetForm = proExampleTargetForm
        self.prepPrepositionType = prepPrepositionType
        self.prepIsFunctionWord = prepIsFunctionWord
        self.prepCoreMeaning = prepCoreMeaning
        self.prepPattern1 = prepPattern1
        self.prepPattern2 = prepPattern2
        self.prepPattern3 = prepPattern3
        self.prepCommonCollocationsRaw = prepCommonCollocationsRaw
        self.prepUsageNote = prepUsageNote
        self.prepMemoryNote = prepMemoryNote
        self.prepExampleTargetForm = prepExampleTargetForm
    }
}
