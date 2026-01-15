//
//  GoodreadsCSVParser.swift
//  Shlf
//
//  Parse Goodreads export CSV
//

#if os(iOS) && !WIDGET_EXTENSION
import Foundation

struct GoodreadsCSVRow {
    let values: [String: String]

    func value(for keys: [String]) -> String? {
        for key in keys {
            let normalized = GoodreadsCSVParser.normalizeHeader(key)
            if let value = values[normalized] {
                let cleaned = GoodreadsCSVParser.normalizeValue(value)
                if !cleaned.isEmpty {
                    return cleaned
                }
            }
        }
        return nil
    }
}

struct GoodreadsImportSummary {
    let totalRows: Int
    let finishedCount: Int
    let currentlyReadingCount: Int
    let wantToReadCount: Int
    let didNotFinishCount: Int
    let ratingsCount: Int
    let datesReadCount: Int
    let customShelvesCount: Int
}

struct GoodreadsImportDocument {
    let headers: [String]
    let rows: [GoodreadsCSVRow]
    let summary: GoodreadsImportSummary
}

enum GoodreadsCSVParser {
    static func parse(data: Data) throws -> GoodreadsImportDocument {
        let text = String(decoding: data, as: UTF8.self)
        let cleaned = text.replacingOccurrences(of: "\u{feff}", with: "")
        let rawRows = parseCSV(cleaned)
        guard let headerRow = rawRows.first else {
            throw GoodreadsImportError.emptyFile
        }

        let headers = headerRow.map { normalizeHeader($0) }
        guard headers.contains("title"), headers.contains("author") else {
            throw GoodreadsImportError.missingRequiredColumns
        }

        let headerIndex = makeHeaderIndex(headers)
        let bodyRows = rawRows.dropFirst().filter { row in
            row.contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        }

        var parsedRows: [GoodreadsCSVRow] = []
        parsedRows.reserveCapacity(bodyRows.count)

        var finishedCount = 0
        var currentlyReadingCount = 0
        var wantToReadCount = 0
        var didNotFinishCount = 0
        var ratingsCount = 0
        var datesReadCount = 0
        var customShelves = Set<String>()

        for row in bodyRows {
            var values: [String: String] = [:]
            for (header, index) in headerIndex {
                if index < row.count {
                    values[header] = row[index]
                }
            }

            let parsedRow = GoodreadsCSVRow(values: values)
            parsedRows.append(parsedRow)

            let exclusiveShelf = parsedRow.value(for: ["exclusive shelf"])?.lowercased()
            switch exclusiveShelf {
            case "read":
                finishedCount += 1
            case "currently-reading":
                currentlyReadingCount += 1
            case "to-read", "want-to-read":
                wantToReadCount += 1
            case "dnf", "did-not-finish", "did not finish":
                didNotFinishCount += 1
            default:
                break
            }

            if let rating = parsedRow.value(for: ["my rating"]), Int(rating) ?? 0 > 0 {
                ratingsCount += 1
            }

            if let dateRead = parsedRow.value(for: ["date read"]), !dateRead.isEmpty {
                datesReadCount += 1
            }

            let shelves = parseShelfList(parsedRow.value(for: ["bookshelves"]))
            let filteredShelves = removeDefaultShelves(shelves, exclusiveShelf: exclusiveShelf)
            for shelf in filteredShelves {
                customShelves.insert(shelf)
            }
        }

        let summary = GoodreadsImportSummary(
            totalRows: parsedRows.count,
            finishedCount: finishedCount,
            currentlyReadingCount: currentlyReadingCount,
            wantToReadCount: wantToReadCount,
            didNotFinishCount: didNotFinishCount,
            ratingsCount: ratingsCount,
            datesReadCount: datesReadCount,
            customShelvesCount: customShelves.count
        )

        return GoodreadsImportDocument(headers: headers, rows: parsedRows, summary: summary)
    }

    static func normalizeHeader(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowercased = trimmed.lowercased()
        let replaced = lowercased
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
        return replaced.replacingOccurrences(of: "  ", with: " ")
    }

    static func normalizeValue(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("=\"") && trimmed.hasSuffix("\"") {
            return String(trimmed.dropFirst(2).dropLast())
        }
        return trimmed
    }

    private static func makeHeaderIndex(_ headers: [String]) -> [String: Int] {
        var map: [String: Int] = [:]
        for (index, header) in headers.enumerated() {
            map[header] = index
        }
        return map
    }

    static func parseShelfList(_ value: String?) -> [String] {
        guard let value else { return [] }
        return value
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private static func removeDefaultShelves(_ shelves: [String], exclusiveShelf: String?) -> [String] {
        return shelves.filter { shelf in
            !isDefaultShelf(shelf, exclusiveShelf: exclusiveShelf)
        }
    }

    private static func isDefaultShelf(_ shelf: String, exclusiveShelf: String?) -> Bool {
        let lower = shelf.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !lower.isEmpty else { return true }
        if let exclusiveLower = exclusiveShelf?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
           lower == exclusiveLower {
            return true
        }

        let reserved = [
            "read",
            "currently-reading",
            "currently reading",
            "to-read",
            "to read",
            "want-to-read",
            "want to read",
            "dnf",
            "did-not-finish",
            "did not finish"
        ]

        for key in reserved {
            if lower == key { return true }
            if lower.hasPrefix(key + " ") ||
                lower.hasPrefix(key + "(") ||
                lower.hasPrefix(key + " (") ||
                lower.hasPrefix(key + " #") ||
                lower.hasPrefix(key + " (#") {
                return true
            }
        }
        return false
    }

    private static func parseCSV(_ text: String) -> [[String]] {
        var rows: [[String]] = []
        var currentRow: [String] = []
        var currentField = ""
        var inQuotes = false
        let characters = Array(text)
        var index = 0

        while index < characters.count {
            let char = characters[index]

            if char == "\"" {
                if inQuotes, index + 1 < characters.count, characters[index + 1] == "\"" {
                    currentField.append("\"")
                    index += 1
                } else {
                    inQuotes.toggle()
                }
            } else if char == "," && !inQuotes {
                currentRow.append(currentField)
                currentField = ""
            } else if (char == "\n" || char == "\r") && !inQuotes {
                if char == "\r", index + 1 < characters.count, characters[index + 1] == "\n" {
                    index += 1
                }
                currentRow.append(currentField)
                rows.append(currentRow)
                currentRow = []
                currentField = ""
            } else {
                currentField.append(char)
            }

            index += 1
        }

        if !currentField.isEmpty || !currentRow.isEmpty {
            currentRow.append(currentField)
            rows.append(currentRow)
        }

        return rows
    }
}
#endif
