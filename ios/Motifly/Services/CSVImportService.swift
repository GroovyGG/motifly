import Foundation
import SwiftData

enum CSVImportService {
    private static let nounImportFlagKey = "motifly.csvImport.seedNouns.v3.done"
    private static let verbImportFlagKey = "motifly.csvImport.seedVerbs.v2.done"
    private static let adjectiveImportFlagKey = "motifly.csvImport.seedAdjectives.v2.done"
    private static let adverbImportFlagKey = "motifly.csvImport.seedAdverbs.v2.done"
    private static let determinerImportFlagKey = "motifly.csvImport.seedDeterminers.v2.done"
    private static let pronounImportFlagKey = "motifly.csvImport.seedPronouns.v2.done"
    private static let prepositionImportFlagKey = "motifly.csvImport.seedPrepositions.v1.done"
    private static let legacyImportFlagKey = "motifly.csvImport.v1.done"

    private static let bundledNounsName = "seed_nouns"
    private static let bundledVerbsName = "seed_verbs"
    private static let bundledAdjectivesName = "seed_adjectives"
    private static let bundledAdverbsName = "seed_adv"
    private static let bundledDeterminersName = "seed_determiners"
    private static let bundledPronounsName = "seed_pronouns"
    private static let bundledPrepositionsName = "seed_prepositions"

    /// Bundled CSVs live under `SeedData/` in the app target (copies of `data_seed/` at repo root).
    private static let bundledSeedsSubdirectory = "SeedData"

    /// Xcode often copies group members into the bundle **root**; folder references may keep `SeedData/`. Resolve both.
    private static func bundledSeedCSVURL(resourceName: String) -> URL? {
        if let url = Bundle.main.url(
            forResource: resourceName,
            withExtension: "csv",
            subdirectory: bundledSeedsSubdirectory
        ) {
            return url
        }
        return Bundle.main.url(forResource: resourceName, withExtension: "csv")
    }

    /// Verbs use `number` from CSV + offset so they never collide with noun `seedNumber` (nouns use 1…~5k).
    nonisolated static let verbSeedNumberOffset = 10_000_000
    /// Adjectives use `number` from CSV + offset (distinct from nouns and verbs).
    nonisolated static let adjectiveSeedNumberOffset = 20_000_000
    /// Adverbs use `number` from CSV + offset (distinct from other kinds).
    nonisolated static let adverbSeedNumberOffset = 30_000_000
    /// Determiners use `number` from CSV + offset (distinct from other kinds).
    nonisolated static let determinerSeedNumberOffset = 40_000_000
    /// Pronouns use `number` from CSV + offset (distinct from other kinds).
    nonisolated static let pronounSeedNumberOffset = 50_000_000
    /// Prepositions use `number` from CSV + offset (distinct from other kinds).
    nonisolated static let prepositionSeedNumberOffset = 60_000_000

    static var needsImport: Bool {
        !UserDefaults.standard.bool(forKey: nounImportFlagKey)
            || !UserDefaults.standard.bool(forKey: verbImportFlagKey)
            || !UserDefaults.standard.bool(forKey: adjectiveImportFlagKey)
            || !UserDefaults.standard.bool(forKey: adverbImportFlagKey)
            || !UserDefaults.standard.bool(forKey: determinerImportFlagKey)
            || !UserDefaults.standard.bool(forKey: pronounImportFlagKey)
            || !UserDefaults.standard.bool(forKey: prepositionImportFlagKey)
    }

    private static func markNounImportFinished() {
        UserDefaults.standard.set(true, forKey: nounImportFlagKey)
        UserDefaults.standard.removeObject(forKey: legacyImportFlagKey)
    }

    private static func markVerbImportFinished() {
        UserDefaults.standard.set(true, forKey: verbImportFlagKey)
    }

    private static func markAdjectiveImportFinished() {
        UserDefaults.standard.set(true, forKey: adjectiveImportFlagKey)
    }

    private static func markAdverbImportFinished() {
        UserDefaults.standard.set(true, forKey: adverbImportFlagKey)
    }

    private static func markDeterminerImportFinished() {
        UserDefaults.standard.set(true, forKey: determinerImportFlagKey)
    }

    private static func markPronounImportFinished() {
        UserDefaults.standard.set(true, forKey: pronounImportFlagKey)
    }

    private static func markPrepositionImportFinished() {
        UserDefaults.standard.set(true, forKey: prepositionImportFlagKey)
    }

    /// Loads bundled noun / verb / adjective / adverb / determiner / pronoun / preposition CSVs off the main actor, then inserts in batches.
    static func importIfNeededAsync(modelContext: ModelContext) async {
        let doNouns = !UserDefaults.standard.bool(forKey: nounImportFlagKey)
        let doVerbs = !UserDefaults.standard.bool(forKey: verbImportFlagKey)
        let doAdjectives = !UserDefaults.standard.bool(forKey: adjectiveImportFlagKey)
        let doAdverbs = !UserDefaults.standard.bool(forKey: adverbImportFlagKey)
        let doDeterminers = !UserDefaults.standard.bool(forKey: determinerImportFlagKey)
        let doPronouns = !UserDefaults.standard.bool(forKey: pronounImportFlagKey)
        let doPrepositions = !UserDefaults.standard.bool(forKey: prepositionImportFlagKey)

        guard doNouns || doVerbs || doAdjectives || doAdverbs || doDeterminers || doPronouns || doPrepositions else { return }

        if doNouns {
            if let url = bundledSeedCSVURL(resourceName: bundledNounsName) {
                await MainActor.run {
                    deleteNounEntries(modelContext: modelContext)
                }

                let rows: [ParsedNounRow] = await Task.detached(priority: .userInitiated) {
                    Self.loadNounRows(from: url)
                }.value

                if rows.isEmpty {
                    print("CSVImportService: parsed 0 noun rows")
                } else {
                    await insertNounBatches(rows: rows, modelContext: modelContext)
                    print("CSVImportService: imported \(rows.count) nouns")
                }
                await MainActor.run { markNounImportFinished() }
            } else {
                print("CSVImportService: \(bundledNounsName).csv missing — skipping noun import")
                await MainActor.run { markNounImportFinished() }
            }
        }

        if doVerbs {
            if let url = bundledSeedCSVURL(resourceName: bundledVerbsName) {
                let rows: [ParsedVerbRow] = await Task.detached(priority: .userInitiated) {
                    Self.loadVerbRows(from: url)
                }.value

                if rows.isEmpty {
                    print("CSVImportService: parsed 0 verb rows")
                } else {
                    await MainActor.run {
                        deleteVerbEntries(modelContext: modelContext)
                    }
                    await insertVerbBatches(rows: rows, modelContext: modelContext)
                    print("CSVImportService: imported \(rows.count) verbs")
                }
                await MainActor.run { markVerbImportFinished() }
            } else {
                print("CSVImportService: \(bundledVerbsName).csv missing — skipping verb import")
                await MainActor.run { markVerbImportFinished() }
            }
        }

        if doAdjectives {
            if let url = bundledSeedCSVURL(resourceName: bundledAdjectivesName) {
                let rows: [ParsedAdjectiveRow] = await Task.detached(priority: .userInitiated) {
                    Self.loadAdjectiveRows(from: url)
                }.value

                if rows.isEmpty {
                    print("CSVImportService: parsed 0 adjective rows")
                } else {
                    await MainActor.run {
                        deleteAdjectiveEntries(modelContext: modelContext)
                    }
                    await insertAdjectiveBatches(rows: rows, modelContext: modelContext)
                    print("CSVImportService: imported \(rows.count) adjectives")
                }
                await MainActor.run { markAdjectiveImportFinished() }
            } else {
                print("CSVImportService: \(bundledAdjectivesName).csv missing — skipping adjective import")
                await MainActor.run { markAdjectiveImportFinished() }
            }
        }

        if doAdverbs {
            if let url = bundledSeedCSVURL(resourceName: bundledAdverbsName) {
                let rows: [ParsedAdverbRow] = await Task.detached(priority: .userInitiated) {
                    Self.loadAdverbRows(from: url)
                }.value

                if rows.isEmpty {
                    print("CSVImportService: parsed 0 adverb rows")
                } else {
                    await MainActor.run {
                        deleteAdverbEntries(modelContext: modelContext)
                    }
                    await insertAdverbBatches(rows: rows, modelContext: modelContext)
                    print("CSVImportService: imported \(rows.count) adverbs")
                }
                await MainActor.run { markAdverbImportFinished() }
            } else {
                print("CSVImportService: \(bundledAdverbsName).csv missing — skipping adverb import")
                await MainActor.run { markAdverbImportFinished() }
            }
        }

        if doDeterminers {
            if let url = bundledSeedCSVURL(resourceName: bundledDeterminersName) {
                let rows: [ParsedDeterminerRow] = await Task.detached(priority: .userInitiated) {
                    Self.loadDeterminerRows(from: url)
                }.value

                if rows.isEmpty {
                    print("CSVImportService: parsed 0 determiner rows")
                } else {
                    await MainActor.run {
                        deleteDeterminerEntries(modelContext: modelContext)
                    }
                    await insertDeterminerBatches(rows: rows, modelContext: modelContext)
                    print("CSVImportService: imported \(rows.count) determiners")
                }
                await MainActor.run { markDeterminerImportFinished() }
            } else {
                print("CSVImportService: \(bundledDeterminersName).csv missing — skipping determiner import")
                await MainActor.run { markDeterminerImportFinished() }
            }
        }

        if doPronouns {
            if let url = bundledSeedCSVURL(resourceName: bundledPronounsName) {
                let rows: [ParsedPronounRow] = await Task.detached(priority: .userInitiated) {
                    Self.loadPronounRows(from: url)
                }.value

                if rows.isEmpty {
                    print("CSVImportService: parsed 0 pronoun rows — not marking pronoun import done")
                } else {
                    await MainActor.run {
                        deletePronounEntries(modelContext: modelContext)
                    }
                    await insertPronounBatches(rows: rows, modelContext: modelContext)
                    print("CSVImportService: imported \(rows.count) pronouns")
                    await MainActor.run { markPronounImportFinished() }
                }
            } else {
                print("CSVImportService: \(bundledPronounsName).csv missing — skipping pronoun import")
            }
        }

        if doPrepositions {
            if let url = bundledSeedCSVURL(resourceName: bundledPrepositionsName) {
                let rows: [ParsedPrepositionRow] = await Task.detached(priority: .userInitiated) {
                    Self.loadPrepositionRows(from: url)
                }.value

                if rows.isEmpty {
                    print("CSVImportService: parsed 0 preposition rows — not marking preposition import done")
                } else {
                    await MainActor.run {
                        deletePrepositionEntries(modelContext: modelContext)
                    }
                    await insertPrepositionBatches(rows: rows, modelContext: modelContext)
                    print("CSVImportService: imported \(rows.count) prepositions")
                    await MainActor.run { markPrepositionImportFinished() }
                }
            } else {
                print("CSVImportService: \(bundledPrepositionsName).csv missing — skipping preposition import")
            }
        }
    }

    @MainActor
    private static func deleteNounEntries(modelContext: ModelContext) {
        let noun = "noun"
        let fd = FetchDescriptor<VocabularyEntry>(
            predicate: #Predicate<VocabularyEntry> { $0.entryKind == nil || $0.entryKind == noun }
        )
        guard let nouns = try? modelContext.fetch(fd) else { return }
        for e in nouns {
            modelContext.delete(e)
        }
        try? modelContext.save()
    }

    @MainActor
    private static func deleteVerbEntries(modelContext: ModelContext) {
        let kind = "verb"
        let fd = FetchDescriptor<VocabularyEntry>(
            predicate: #Predicate<VocabularyEntry> { $0.entryKind == kind }
        )
        guard let verbs = try? modelContext.fetch(fd) else { return }
        for e in verbs {
            modelContext.delete(e)
        }
        try? modelContext.save()
    }

    @MainActor
    private static func deleteAdjectiveEntries(modelContext: ModelContext) {
        let kind = "adjective"
        let fd = FetchDescriptor<VocabularyEntry>(
            predicate: #Predicate<VocabularyEntry> { $0.entryKind == kind }
        )
        guard let items = try? modelContext.fetch(fd) else { return }
        for e in items {
            modelContext.delete(e)
        }
        try? modelContext.save()
    }

    @MainActor
    private static func deleteAdverbEntries(modelContext: ModelContext) {
        let kind = "adverb"
        let fd = FetchDescriptor<VocabularyEntry>(
            predicate: #Predicate<VocabularyEntry> { $0.entryKind == kind }
        )
        guard let items = try? modelContext.fetch(fd) else { return }
        for e in items {
            modelContext.delete(e)
        }
        try? modelContext.save()
    }

    @MainActor
    private static func deleteDeterminerEntries(modelContext: ModelContext) {
        let kind = "determiner"
        let fd = FetchDescriptor<VocabularyEntry>(
            predicate: #Predicate<VocabularyEntry> { $0.entryKind == kind }
        )
        guard let items = try? modelContext.fetch(fd) else { return }
        for e in items {
            modelContext.delete(e)
        }
        try? modelContext.save()
    }

    @MainActor
    private static func deletePronounEntries(modelContext: ModelContext) {
        let kind = "pronoun"
        let fd = FetchDescriptor<VocabularyEntry>(
            predicate: #Predicate<VocabularyEntry> { $0.entryKind == kind }
        )
        guard let items = try? modelContext.fetch(fd) else { return }
        for e in items {
            modelContext.delete(e)
        }
        try? modelContext.save()
    }

    @MainActor
    private static func deletePrepositionEntries(modelContext: ModelContext) {
        let kind = "preposition"
        let fd = FetchDescriptor<VocabularyEntry>(
            predicate: #Predicate<VocabularyEntry> { $0.entryKind == kind }
        )
        guard let items = try? modelContext.fetch(fd) else { return }
        for e in items {
            modelContext.delete(e)
        }
        try? modelContext.save()
    }

    private static func insertNounBatches(rows: [ParsedNounRow], modelContext: ModelContext) async {
        let batchSize = 200
        var index = 0
        while index < rows.count {
            let end = min(index + batchSize, rows.count)
            let batch = Array(rows[index..<end])
            await MainActor.run {
                for row in batch {
                    let entry = VocabularyEntry(
                        seedNumber: row.seedNumber,
                        frenchLemma: row.frenchLemma,
                        english: row.english,
                        pos: row.pos,
                        thematic: row.thematic,
                        exampleFrench: row.exampleFrench,
                        exampleEnglish: row.exampleEnglish,
                        entryKind: "noun",
                        chineseExplanation: row.chineseExplanation.trimmedOrNil,
                        genderCode: row.genderCode.trimmedOrNil,
                        lemmaArticle: row.lemmaArticle.trimmedOrNil,
                        pluralForm: row.pluralForm.trimmedOrNil,
                        pluralType: row.pluralType.trimmedOrNil
                    )
                    modelContext.insert(entry)
                }
                try? modelContext.save()
            }
            await Task.yield()
            index = end
        }
        await MainActor.run { try? modelContext.save() }
    }

    private static func insertVerbBatches(rows: [ParsedVerbRow], modelContext: ModelContext) async {
        let batchSize = 200
        var index = 0
        while index < rows.count {
            let end = min(index + batchSize, rows.count)
            let batch = Array(rows[index..<end])
            await MainActor.run {
                for row in batch {
                    let entry = VocabularyEntry(
                        seedNumber: row.seedNumber,
                        frenchLemma: row.frenchLemma,
                        english: row.english,
                        pos: row.pos,
                        thematic: row.thematic,
                        exampleFrench: row.exampleFrench,
                        exampleEnglish: row.exampleEnglish,
                        entryKind: "verb",
                        chineseExplanation: row.chineseExplanation.trimmedOrNil,
                        verbGroup: row.verbGroup.trimmedOrNil,
                        verbAuxiliary: row.verbAuxiliary.trimmedOrNil,
                        verbPastParticiple: row.pastParticiple.trimmedOrNil,
                        verbPresentJSON: row.presentJSON,
                        verbPasseComposeJSON: row.passeComposeJSON
                    )
                    modelContext.insert(entry)
                }
                try? modelContext.save()
            }
            await Task.yield()
            index = end
        }
        await MainActor.run { try? modelContext.save() }
    }

    private static func insertAdjectiveBatches(rows: [ParsedAdjectiveRow], modelContext: ModelContext) async {
        let batchSize = 200
        var index = 0
        while index < rows.count {
            let end = min(index + batchSize, rows.count)
            let batch = Array(rows[index..<end])
            await MainActor.run {
                for row in batch {
                    let entry = VocabularyEntry(
                        seedNumber: row.seedNumber,
                        frenchLemma: row.frenchLemma,
                        english: row.english,
                        pos: row.pos,
                        thematic: row.thematic,
                        exampleFrench: row.exampleFrench,
                        exampleEnglish: row.exampleEnglish,
                        entryKind: "adjective",
                        chineseExplanation: row.chineseExplanation.trimmedOrNil,
                        adjMascSingular: row.mascSingular.trimmedOrNil,
                        adjFemSingular: row.femSingular.trimmedOrNil,
                        adjMascPlural: row.mascPlural.trimmedOrNil,
                        adjFemPlural: row.femPlural.trimmedOrNil,
                        adjAdjectiveType: row.adjectiveType.trimmedOrNil,
                        adjInvariable: row.invariable,
                        adjMemoryNote: row.memoryNote.trimmedOrNil,
                        adjExampleTargetForm: row.exampleTargetForm.trimmedOrNil
                    )
                    modelContext.insert(entry)
                }
                try? modelContext.save()
            }
            await Task.yield()
            index = end
        }
        await MainActor.run { try? modelContext.save() }
    }

    private static func insertAdverbBatches(rows: [ParsedAdverbRow], modelContext: ModelContext) async {
        let batchSize = 200
        var index = 0
        while index < rows.count {
            let end = min(index + batchSize, rows.count)
            let batch = Array(rows[index..<end])
            await MainActor.run {
                for row in batch {
                    let entry = VocabularyEntry(
                        seedNumber: row.seedNumber,
                        frenchLemma: row.frenchLemma,
                        english: row.english,
                        pos: row.pos,
                        thematic: row.thematic,
                        exampleFrench: row.exampleFrench,
                        exampleEnglish: row.exampleEnglish,
                        entryKind: "adverb",
                        chineseExplanation: row.chineseExplanation.trimmedOrNil,
                        advAdverbType: row.adverbType.trimmedOrNil,
                        advFormation: row.formation.trimmedOrNil,
                        advIsInvariable: row.invariable,
                        advPlacementPosition: row.placementPosition.trimmedOrNil,
                        advPlacementNote: row.placementNote.trimmedOrNil,
                        advPlacementExampleFront: row.placementExampleFront.trimmedOrNil,
                        advPlacementExampleEnd: row.placementExampleEnd.trimmedOrNil,
                        advMemoryNote: row.memoryNote.trimmedOrNil,
                        advExampleTargetForm: row.exampleTargetForm.trimmedOrNil
                    )
                    modelContext.insert(entry)
                }
                try? modelContext.save()
            }
            await Task.yield()
            index = end
        }
        await MainActor.run { try? modelContext.save() }
    }

    private static func insertDeterminerBatches(rows: [ParsedDeterminerRow], modelContext: ModelContext) async {
        let batchSize = 200
        var index = 0
        while index < rows.count {
            let end = min(index + batchSize, rows.count)
            let batch = Array(rows[index..<end])
            await MainActor.run {
                for row in batch {
                    let entry = VocabularyEntry(
                        seedNumber: row.seedNumber,
                        frenchLemma: row.frenchLemma,
                        english: row.english,
                        pos: row.pos,
                        thematic: row.thematic,
                        exampleFrench: row.exampleFrench,
                        exampleEnglish: row.exampleEnglish,
                        entryKind: "determiner",
                        chineseExplanation: row.chineseExplanation.trimmedOrNil,
                        detDeterminerType: row.determinerType.trimmedOrNil,
                        detUsageNote: row.usageNote.trimmedOrNil,
                        detMascSingular: row.mascSingular.trimmedOrNil,
                        detFemSingular: row.femSingular.trimmedOrNil,
                        detMascPlural: row.mascPlural.trimmedOrNil,
                        detFemPlural: row.femPlural.trimmedOrNil,
                        detNounPatternsRaw: row.nounPattern.trimmedOrNil,
                        detExampleTargetForm: row.exampleTargetForm.trimmedOrNil
                    )
                    modelContext.insert(entry)
                }
                try? modelContext.save()
            }
            await Task.yield()
            index = end
        }
        await MainActor.run { try? modelContext.save() }
    }

    private static func insertPronounBatches(rows: [ParsedPronounRow], modelContext: ModelContext) async {
        let batchSize = 200
        var index = 0
        while index < rows.count {
            let end = min(index + batchSize, rows.count)
            let batch = Array(rows[index..<end])
            await MainActor.run {
                for row in batch {
                    let entry = VocabularyEntry(
                        seedNumber: row.seedNumber,
                        frenchLemma: row.frenchLemma,
                        english: row.english,
                        pos: row.pos,
                        thematic: row.thematic,
                        exampleFrench: row.exampleFrench,
                        exampleEnglish: row.exampleEnglish,
                        entryKind: "pronoun",
                        chineseExplanation: row.chineseExplanation.trimmedOrNil,
                        proPronounType: row.pronounType.trimmedOrNil,
                        proIsFunctionWord: row.isFunctionWord,
                        proPerson: row.person.trimmedOrNil,
                        proNumberFeature: row.numberFeature.trimmedOrNil,
                        proGenderFeature: row.genderFeature.trimmedOrNil,
                        proReplacesWhat: row.replacesWhat.trimmedOrNil,
                        proPositionNote: row.positionNote.trimmedOrNil,
                        proPositionExamplesRaw: row.positionExamples.trimmedOrNil,
                        proUsageNote: row.usageNote.trimmedOrNil,
                        proMemoryNote: row.memoryNote.trimmedOrNil,
                        proExampleTargetForm: row.exampleTargetForm.trimmedOrNil
                    )
                    modelContext.insert(entry)
                }
                try? modelContext.save()
            }
            await Task.yield()
            index = end
        }
        await MainActor.run { try? modelContext.save() }
    }

    private static func insertPrepositionBatches(rows: [ParsedPrepositionRow], modelContext: ModelContext) async {
        let batchSize = 200
        var index = 0
        while index < rows.count {
            let end = min(index + batchSize, rows.count)
            let batch = Array(rows[index..<end])
            await MainActor.run {
                for row in batch {
                    let entry = VocabularyEntry(
                        seedNumber: row.seedNumber,
                        frenchLemma: row.frenchLemma,
                        english: row.english,
                        pos: row.pos,
                        thematic: row.thematic,
                        exampleFrench: row.exampleFrench,
                        exampleEnglish: row.exampleEnglish,
                        entryKind: "preposition",
                        chineseExplanation: row.chineseExplanation.trimmedOrNil,
                        prepPrepositionType: row.prepositionType.trimmedOrNil,
                        prepIsFunctionWord: row.isFunctionWord,
                        prepCoreMeaning: row.coreMeaning.trimmedOrNil,
                        prepPattern1: row.pattern1.trimmedOrNil,
                        prepPattern2: row.pattern2.trimmedOrNil,
                        prepPattern3: row.pattern3.trimmedOrNil,
                        prepCommonCollocationsRaw: row.commonCollocations.trimmedOrNil,
                        prepUsageNote: row.usageNote.trimmedOrNil,
                        prepMemoryNote: row.memoryNote.trimmedOrNil,
                        prepExampleTargetForm: row.exampleTargetForm.trimmedOrNil
                    )
                    modelContext.insert(entry)
                }
                try? modelContext.save()
            }
            await Task.yield()
            index = end
        }
        await MainActor.run { try? modelContext.save() }
    }

    // MARK: - Noun parsing

    private struct ParsedNounRow {
        let seedNumber: Int
        let frenchLemma: String
        let english: String
        let pos: String
        let thematic: String
        let exampleFrench: String
        let exampleEnglish: String
        let chineseExplanation: String
        let genderCode: String
        let lemmaArticle: String
        let pluralForm: String
        let pluralType: String
    }

    private nonisolated static func loadNounRows(from url: URL) -> [ParsedNounRow] {
        guard let data = try? Data(contentsOf: url),
              var text = String(data: data, encoding: .utf8) else { return [] }

        if text.hasPrefix("\u{FEFF}") {
            text.removeFirst()
        }

        let lines = text.split(whereSeparator: \.isNewline).map(String.init)
        guard lines.count >= 2 else { return [] }

        let headerFields = parseCSVFields(lines[0]).map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard !headerFields.isEmpty else { return [] }

        var out: [ParsedNounRow] = []
        out.reserveCapacity(lines.count - 1)

        for line in lines.dropFirst() {
            guard !line.isEmpty else { continue }
            let fields = parseCSVFields(line)
            guard fields.count >= headerFields.count else { continue }

            var row: [String: String] = [:]
            for (i, key) in headerFields.enumerated() where i < fields.count {
                row[key] = fields[i]
            }

            guard let num = Int(row["number"]?.trimmingCharacters(in: .whitespaces) ?? "") else { continue }

            out.append(
                ParsedNounRow(
                    seedNumber: num,
                    frenchLemma: row["french_lemma"] ?? "",
                    english: row["english"] ?? "",
                    pos: row["pos"] ?? "",
                    thematic: row["thematic"] ?? "",
                    exampleFrench: row["example_french"] ?? "",
                    exampleEnglish: row["example_english"] ?? "",
                    chineseExplanation: row["chinese_explanation"] ?? "",
                    genderCode: row["gender"] ?? "",
                    lemmaArticle: row["lemma_article"] ?? "",
                    pluralForm: row["plural_form"] ?? "",
                    pluralType: row["plural_type"] ?? ""
                )
            )
        }
        return out
    }

    // MARK: - Verb parsing

    private struct ParsedVerbRow {
        let seedNumber: Int
        let frenchLemma: String
        let english: String
        let pos: String
        let thematic: String
        let exampleFrench: String
        let exampleEnglish: String
        let chineseExplanation: String
        let verbGroup: String
        let verbAuxiliary: String
        let pastParticiple: String
        let presentJSON: String
        let passeComposeJSON: String
    }

    private nonisolated static func loadVerbRows(from url: URL) -> [ParsedVerbRow] {
        guard let data = try? Data(contentsOf: url),
              var text = String(data: data, encoding: .utf8) else { return [] }

        if text.hasPrefix("\u{FEFF}") {
            text.removeFirst()
        }

        let lines = text.split(whereSeparator: \.isNewline).map(String.init)
        guard lines.count >= 2 else { return [] }

        let headerFields = parseCSVFields(lines[0]).map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard !headerFields.isEmpty else { return [] }

        var out: [ParsedVerbRow] = []
        out.reserveCapacity(lines.count - 1)

        for line in lines.dropFirst() {
            guard !line.isEmpty else { continue }
            let fields = parseCSVFields(line)
            guard fields.count >= headerFields.count else { continue }

            var row: [String: String] = [:]
            for (i, key) in headerFields.enumerated() where i < fields.count {
                row[key] = fields[i]
            }

            guard let num = Int(row["number"]?.trimmingCharacters(in: .whitespaces) ?? "") else { continue }

            let seedNumber = verbSeedNumberOffset + num
            let presentJSON = conjugationJSON(row: row, persons: [
                ("je", "present_je"), ("tu", "present_tu"), ("il/elle", "present_il_elle"),
                ("nous", "present_nous"), ("vous", "present_vous"), ("ils/elles", "present_ils_elles"),
            ])
            let pcJSON = conjugationJSON(row: row, persons: [
                ("je", "pc_je"), ("tu", "pc_tu"), ("il/elle", "pc_il_elle"),
                ("nous", "pc_nous"), ("vous", "pc_vous"), ("ils/elles", "pc_ils_elles"),
            ])

            out.append(
                ParsedVerbRow(
                    seedNumber: seedNumber,
                    frenchLemma: row["french_lemma"] ?? "",
                    english: row["english"] ?? "",
                    pos: row["pos"] ?? "",
                    thematic: row["thematic"] ?? "",
                    exampleFrench: row["example_french"] ?? "",
                    exampleEnglish: row["example_english"] ?? "",
                    chineseExplanation: row["chinese_explanation"] ?? "",
                    verbGroup: row["verb_group"] ?? "",
                    verbAuxiliary: row["auxiliary"] ?? "",
                    pastParticiple: row["past_participle"] ?? "",
                    presentJSON: presentJSON,
                    passeComposeJSON: pcJSON
                )
            )
        }
        return out
    }

    // MARK: - Adjective parsing

    private struct ParsedAdjectiveRow {
        let seedNumber: Int
        let frenchLemma: String
        let english: String
        let pos: String
        let thematic: String
        let exampleFrench: String
        let exampleEnglish: String
        let chineseExplanation: String
        let mascSingular: String
        let femSingular: String
        let mascPlural: String
        let femPlural: String
        let adjectiveType: String
        let invariable: Bool
        let memoryNote: String
        let exampleTargetForm: String
    }

    private nonisolated static func loadAdjectiveRows(from url: URL) -> [ParsedAdjectiveRow] {
        guard let data = try? Data(contentsOf: url),
              var text = String(data: data, encoding: .utf8) else { return [] }

        if text.hasPrefix("\u{FEFF}") {
            text.removeFirst()
        }

        let lines = text.split(whereSeparator: \.isNewline).map(String.init)
        guard lines.count >= 2 else { return [] }

        let headerFields = parseCSVFields(lines[0]).map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard !headerFields.isEmpty else { return [] }

        var out: [ParsedAdjectiveRow] = []
        out.reserveCapacity(lines.count - 1)

        for line in lines.dropFirst() {
            guard !line.isEmpty else { continue }
            let fields = parseCSVFields(line)
            guard fields.count >= headerFields.count else { continue }

            var row: [String: String] = [:]
            for (i, key) in headerFields.enumerated() where i < fields.count {
                row[key] = fields[i]
            }

            guard let num = Int(row["number"]?.trimmingCharacters(in: .whitespaces) ?? "") else { continue }

            let seedNumber = adjectiveSeedNumberOffset + num
            let inv = (row["is_invariable"] ?? "").lowercased() == "true"

            out.append(
                ParsedAdjectiveRow(
                    seedNumber: seedNumber,
                    frenchLemma: row["french_lemma"] ?? "",
                    english: row["english"] ?? "",
                    pos: row["pos"] ?? "",
                    thematic: row["thematic"] ?? "",
                    exampleFrench: row["example_french"] ?? "",
                    exampleEnglish: row["example_english"] ?? "",
                    chineseExplanation: row["chinese_translation"] ?? "",
                    mascSingular: row["masc_singular"] ?? "",
                    femSingular: row["fem_singular"] ?? "",
                    mascPlural: row["masc_plural"] ?? "",
                    femPlural: row["fem_plural"] ?? "",
                    adjectiveType: row["adjective_type"] ?? "",
                    invariable: inv,
                    memoryNote: row["memory_note"] ?? "",
                    exampleTargetForm: row["example_target_form"] ?? ""
                )
            )
        }
        return out
    }

    // MARK: - Adverb parsing

    private struct ParsedAdverbRow {
        let seedNumber: Int
        let frenchLemma: String
        let english: String
        let pos: String
        let thematic: String
        let exampleFrench: String
        let exampleEnglish: String
        let chineseExplanation: String
        let adverbType: String
        let formation: String
        let invariable: Bool?
        let placementPosition: String
        let placementNote: String
        let placementExampleFront: String
        let placementExampleEnd: String
        let memoryNote: String
        let exampleTargetForm: String
    }

    private nonisolated static func loadAdverbRows(from url: URL) -> [ParsedAdverbRow] {
        guard let data = try? Data(contentsOf: url),
              var text = String(data: data, encoding: .utf8) else { return [] }

        if text.hasPrefix("\u{FEFF}") {
            text.removeFirst()
        }

        let lines = text.split(whereSeparator: \.isNewline).map(String.init)
        guard lines.count >= 2 else { return [] }

        let headerFields = parseCSVFields(lines[0]).map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard !headerFields.isEmpty else { return [] }

        var out: [ParsedAdverbRow] = []
        out.reserveCapacity(lines.count - 1)

        for line in lines.dropFirst() {
            guard !line.isEmpty else { continue }
            let fields = parseCSVFields(line)
            guard fields.count >= headerFields.count else { continue }

            var row: [String: String] = [:]
            for (i, key) in headerFields.enumerated() where i < fields.count {
                row[key] = fields[i]
            }

            guard let num = Int(row["number"]?.trimmingCharacters(in: .whitespaces) ?? "") else { continue }

            let seedNumber = adverbSeedNumberOffset + num
            let invStr = (row["is_invariable"] ?? "").lowercased()
            let inv: Bool? = invStr == "true" ? true : (invStr == "false" ? false : nil)

            out.append(
                ParsedAdverbRow(
                    seedNumber: seedNumber,
                    frenchLemma: row["french_lemma"] ?? "",
                    english: row["english"] ?? "",
                    pos: row["pos"] ?? "",
                    thematic: row["thematic"] ?? "",
                    exampleFrench: row["example_french"] ?? "",
                    exampleEnglish: row["example_english"] ?? "",
                    chineseExplanation: row["chinese_translation"] ?? "",
                    adverbType: row["adverb_type"] ?? "",
                    formation: row["formation"] ?? "",
                    invariable: inv,
                    placementPosition: row["placement_position"] ?? "",
                    placementNote: row["placement_note"] ?? "",
                    placementExampleFront: row["placement_example_front"] ?? "",
                    placementExampleEnd: row["placement_example_end"] ?? "",
                    memoryNote: row["memory_note"] ?? "",
                    exampleTargetForm: row["example_target_form"] ?? ""
                )
            )
        }
        return out
    }

    // MARK: - Determiner parsing

    private struct ParsedDeterminerRow {
        let seedNumber: Int
        let frenchLemma: String
        let english: String
        let pos: String
        let thematic: String
        let exampleFrench: String
        let exampleEnglish: String
        let chineseExplanation: String
        let determinerType: String
        let mascSingular: String
        let femSingular: String
        let mascPlural: String
        let femPlural: String
        let nounPattern: String
        let usageNote: String
        let exampleTargetForm: String
    }

    private nonisolated static func loadDeterminerRows(from url: URL) -> [ParsedDeterminerRow] {
        guard let data = try? Data(contentsOf: url),
              var text = String(data: data, encoding: .utf8) else { return [] }

        if text.hasPrefix("\u{FEFF}") {
            text.removeFirst()
        }

        let lines = text.split(whereSeparator: \.isNewline).map(String.init)
        guard lines.count >= 2 else { return [] }

        let headerFields = parseCSVFields(lines[0]).map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard !headerFields.isEmpty else { return [] }

        var out: [ParsedDeterminerRow] = []
        out.reserveCapacity(lines.count - 1)

        for line in lines.dropFirst() {
            guard !line.isEmpty else { continue }
            let fields = parseCSVFields(line)
            guard fields.count >= headerFields.count else { continue }

            var row: [String: String] = [:]
            for (i, key) in headerFields.enumerated() where i < fields.count {
                row[key] = fields[i]
            }

            guard let num = Int(row["number"]?.trimmingCharacters(in: .whitespaces) ?? "") else { continue }

            let seedNumber = determinerSeedNumberOffset + num

            out.append(
                ParsedDeterminerRow(
                    seedNumber: seedNumber,
                    frenchLemma: row["french_lemma"] ?? "",
                    english: row["english"] ?? "",
                    pos: row["pos"] ?? "",
                    thematic: row["thematic"] ?? "none",
                    exampleFrench: row["example_french"] ?? "",
                    exampleEnglish: row["example_english"] ?? "",
                    chineseExplanation: row["chinese_translation"] ?? "",
                    determinerType: row["determiner_type"] ?? "",
                    mascSingular: row["masc_singular"] ?? "",
                    femSingular: row["fem_singular"] ?? "",
                    mascPlural: row["masc_plural"] ?? "",
                    femPlural: row["fem_plural"] ?? "",
                    nounPattern: row["noun_pattern"] ?? "",
                    usageNote: row["usage_note"] ?? "",
                    exampleTargetForm: row["example_target_form"] ?? ""
                )
            )
        }
        return out
    }

    // MARK: - Pronoun parsing

    private struct ParsedPronounRow {
        let seedNumber: Int
        let frenchLemma: String
        let english: String
        let pos: String
        let thematic: String
        let exampleFrench: String
        let exampleEnglish: String
        let chineseExplanation: String
        let pronounType: String
        let isFunctionWord: Bool?
        let person: String
        let numberFeature: String
        let genderFeature: String
        let replacesWhat: String
        let positionNote: String
        let positionExamples: String
        let usageNote: String
        let memoryNote: String
        let exampleTargetForm: String
    }

    private nonisolated static func loadPronounRows(from url: URL) -> [ParsedPronounRow] {
        guard let data = try? Data(contentsOf: url),
              var text = String(data: data, encoding: .utf8) else { return [] }

        if text.hasPrefix("\u{FEFF}") {
            text.removeFirst()
        }

        let lines = text.split(whereSeparator: \.isNewline).map(String.init)
        guard lines.count >= 2 else { return [] }

        let headerFields = parseCSVFields(lines[0]).map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard !headerFields.isEmpty else { return [] }

        var out: [ParsedPronounRow] = []
        out.reserveCapacity(lines.count - 1)

        for line in lines.dropFirst() {
            guard !line.isEmpty else { continue }
            let fields = parseCSVFields(line)
            guard fields.count >= headerFields.count else { continue }

            var row: [String: String] = [:]
            for (i, key) in headerFields.enumerated() where i < fields.count {
                row[key] = fields[i]
            }

            guard let num = Int(row["number"]?.trimmingCharacters(in: .whitespaces) ?? "") else { continue }

            let seedNumber = pronounSeedNumberOffset + num
            let fwStr = (row["is_function_word"] ?? "").lowercased()
            let fw: Bool? = fwStr == "true" ? true : (fwStr == "false" ? false : nil)

            out.append(
                ParsedPronounRow(
                    seedNumber: seedNumber,
                    frenchLemma: row["french_lemma"] ?? "",
                    english: row["english"] ?? "",
                    pos: row["pos"] ?? "",
                    thematic: row["thematic"] ?? "none",
                    exampleFrench: row["example_french"] ?? "",
                    exampleEnglish: row["example_english"] ?? "",
                    chineseExplanation: row["chinese_translation"] ?? "",
                    pronounType: row["pronoun_type"] ?? "",
                    isFunctionWord: fw,
                    person: row["person"] ?? "",
                    numberFeature: row["number_feature"] ?? "",
                    genderFeature: row["gender_feature"] ?? "",
                    replacesWhat: row["replaces_what"] ?? "",
                    positionNote: row["position_note"] ?? "",
                    positionExamples: row["position_examples"] ?? "",
                    usageNote: row["usage_note"] ?? "",
                    memoryNote: row["memory_note"] ?? "",
                    exampleTargetForm: row["example_target_form"] ?? ""
                )
            )
        }
        return out
    }

    // MARK: - Preposition parsing

    private struct ParsedPrepositionRow {
        let seedNumber: Int
        let frenchLemma: String
        let english: String
        let pos: String
        let thematic: String
        let exampleFrench: String
        let exampleEnglish: String
        let chineseExplanation: String
        let prepositionType: String
        let isFunctionWord: Bool?
        let coreMeaning: String
        let pattern1: String
        let pattern2: String
        let pattern3: String
        let commonCollocations: String
        let usageNote: String
        let memoryNote: String
        let exampleTargetForm: String
    }

    private nonisolated static func loadPrepositionRows(from url: URL) -> [ParsedPrepositionRow] {
        guard let data = try? Data(contentsOf: url),
              var text = String(data: data, encoding: .utf8) else { return [] }

        if text.hasPrefix("\u{FEFF}") {
            text.removeFirst()
        }

        let lines = text.split(whereSeparator: \.isNewline).map(String.init)
        guard lines.count >= 2 else { return [] }

        let headerFields = parseCSVFields(lines[0]).map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard !headerFields.isEmpty else { return [] }

        var out: [ParsedPrepositionRow] = []
        out.reserveCapacity(lines.count - 1)

        for line in lines.dropFirst() {
            guard !line.isEmpty else { continue }
            let fields = parseCSVFields(line)
            guard fields.count >= headerFields.count else { continue }

            var row: [String: String] = [:]
            for (i, key) in headerFields.enumerated() where i < fields.count {
                row[key] = fields[i]
            }

            guard let num = Int(row["number"]?.trimmingCharacters(in: .whitespaces) ?? "") else { continue }

            let seedNumber = prepositionSeedNumberOffset + num
            let fwStr = (row["is_function_word"] ?? "").lowercased()
            let fw: Bool? = fwStr == "true" ? true : (fwStr == "false" ? false : nil)

            out.append(
                ParsedPrepositionRow(
                    seedNumber: seedNumber,
                    frenchLemma: row["french_lemma"] ?? "",
                    english: row["english"] ?? "",
                    pos: row["pos"] ?? "",
                    thematic: "none",
                    exampleFrench: row["example_french"] ?? "",
                    exampleEnglish: row["example_english"] ?? "",
                    chineseExplanation: row["chinese_translation"] ?? "",
                    prepositionType: row["preposition_type"] ?? "",
                    isFunctionWord: fw,
                    coreMeaning: row["core_meaning"] ?? "",
                    pattern1: row["pattern_1"] ?? "",
                    pattern2: row["pattern_2"] ?? "",
                    pattern3: row["pattern_3"] ?? "",
                    commonCollocations: row["common_collocations"] ?? "",
                    usageNote: row["usage_note"] ?? "",
                    memoryNote: row["memory_note"] ?? "",
                    exampleTargetForm: row["example_target_form"] ?? ""
                )
            )
        }
        return out
    }

    private nonisolated static func conjugationJSON(
        row: [String: String],
        persons: [(String, String)]
    ) -> String {
        struct Pair: Codable {
            let person: String
            let form: String
        }
        var pairs: [Pair] = []
        for (label, key) in persons {
            let raw = row[key]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !raw.isEmpty {
                pairs.append(Pair(person: label, form: raw))
            }
        }
        guard let data = try? JSONEncoder().encode(pairs),
              let s = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return s
    }

    /// Splits one CSV line into fields (supports quoted commas).
    private nonisolated static func parseCSVFields(_ line: String) -> [String] {
        var fields: [String] = []
        var current = ""
        var inQuotes = false
        for ch in line {
            if ch == "\"" {
                inQuotes.toggle()
            } else if ch == "," && !inQuotes {
                fields.append(current)
                current = ""
            } else {
                current.append(ch)
            }
        }
        fields.append(current)
        return fields
    }
}

private extension String {
    var trimmedOrNil: String? {
        let t = trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }
}
