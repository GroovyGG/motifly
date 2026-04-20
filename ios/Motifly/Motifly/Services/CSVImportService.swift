import Foundation
import SwiftData

enum CSVImportService {
    private static let importFlagKey = "motifly.csvImport.v1.done"

    static var needsImport: Bool {
        !UserDefaults.standard.bool(forKey: importFlagKey)
    }

    private static func markImportFinished() {
        UserDefaults.standard.set(true, forKey: importFlagKey)
    }

    /// Loads and parses CSV off the main actor, then inserts in batches so the UI can render.
    static func importIfNeededAsync(modelContext: ModelContext) async {
        guard needsImport else { return }

        guard let url = Bundle.main.url(forResource: "french_5000", withExtension: "csv") else {
            print("CSVImportService: french_5000.csv not in bundle — marking import finished to avoid a stuck launch")
            markImportFinished()
            return
        }

        let rows: [ParsedCSVRow] = await Task.detached(priority: .userInitiated) {
            Self.loadRows(from: url)
        }.value

        guard !rows.isEmpty else {
            print("CSVImportService: parsed 0 rows — check CSV; marking import finished so the app can run")
            markImportFinished()
            return
        }

        let batchSize = 200
        var inserted = 0
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
                        exampleEnglish: row.exampleEnglish
                    )
                    modelContext.insert(entry)
                    inserted += 1
                }
                do {
                    try modelContext.save()
                } catch {
                    print("CSVImportService batch save error: \(error)")
                }
            }
            await Task.yield()
            index = end
        }

        await MainActor.run {
            do {
                try modelContext.save()
                markImportFinished()
                print("CSVImportService: imported \(inserted) rows")
            } catch {
                print("CSVImportService final save error: \(error)")
            }
        }
    }

    private struct ParsedCSVRow {
        let seedNumber: Int
        let frenchLemma: String
        let english: String
        let pos: String
        let thematic: String
        let exampleFrench: String
        let exampleEnglish: String
    }

    private nonisolated static func loadRows(from url: URL) -> [ParsedCSVRow] {
        guard let data = try? Data(contentsOf: url),
              var text = String(data: data, encoding: .utf8) else { return [] }

        if text.hasPrefix("\u{FEFF}") {
            text.removeFirst()
        }

        let lines = text.split(whereSeparator: \.isNewline).map(String.init)
        guard lines.count >= 2 else { return [] }

        var out: [ParsedCSVRow] = []
        out.reserveCapacity(lines.count - 1)

        for line in lines.dropFirst() {
            guard !line.isEmpty else { continue }
            guard let row = parseCSVLine(line),
                  let num = Int(row["number"] ?? "") else { continue }

            out.append(
                ParsedCSVRow(
                    seedNumber: num,
                    frenchLemma: row["french_lemma"] ?? "",
                    english: row["english"] ?? "",
                    pos: row["pos"] ?? "",
                    thematic: row["thematic"] ?? "",
                    exampleFrench: row["example_french"] ?? "",
                    exampleEnglish: row["example_english"] ?? ""
                )
            )
        }
        return out
    }

    /// Minimal CSV parser with quote support for fields containing commas.
    private nonisolated static func parseCSVLine(_ line: String) -> [String: String]? {
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

        let header = [
            "number", "french_lemma", "thematic", "pos", "english", "example",
            "example_french", "word count", "example_english", "range_count",
            "frequency_raw", "range_pipe_frequency",
        ]
        guard fields.count >= header.count else { return nil }
        var dict: [String: String] = [:]
        for (i, key) in header.enumerated() where i < fields.count {
            dict[key] = fields[i]
        }
        return dict
    }
}
