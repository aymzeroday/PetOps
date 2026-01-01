import Foundation

struct ExtractedReceipt {
    var total: Decimal?
    var currency: String?
    var vendor: String?
    var date: Date?
}

struct ExtractedVaccine {
    var vaccineName: String?
    var date: Date?
}

enum DocExtractor {

    static func extractReceipt(ocr: String) -> ExtractedReceipt {
        let lines: [String] = ocr
            .split(separator: "\n")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }

        var out = ExtractedReceipt()

        // Vendor: first non-empty line (weak heuristic)
        out.vendor = lines.first(where: { !$0.isEmpty })

        // Currency guess
        let lower = ocr.lowercased()
        if lower.contains("kwd") || lower.contains(" kd") || lower.contains("k.d") { out.currency = "KWD" }
        else if lower.contains("usd") { out.currency = "USD" }
        else if lower.contains("eur") { out.currency = "EUR" }

        // Total: look for "total" line then parse last number
        if let totalLine = lines.first(where: { $0.lowercased().contains("total") }) {
            out.total = parseLastDecimal(in: totalLine)
        } else {
            // fallback: parse largest decimal in whole text
            out.total = parseLargestDecimal(in: ocr)
        }

        // Date: first recognizable date
        out.date = parseFirstDate(in: ocr)

        return out
    }

    static func extractVaccine(ocr: String) -> ExtractedVaccine {
        let lower = ocr.lowercased()
        var out = ExtractedVaccine()

        let known = ["rabies", "fvr", "feline", "distemper", "parvo", "booster"]
        out.vaccineName = known.first(where: { lower.contains($0) }).map { $0.capitalized } ?? "Vaccine"
        out.date = parseFirstDate(in: ocr)

        return out
    }

    private static func parseLastDecimal(in line: String) -> Decimal? {
        decimals(in: line).last
    }

    private static func parseLargestDecimal(in text: String) -> Decimal? {
        decimals(in: text).max()
    }

    private static func decimals(in text: String) -> [Decimal] {
        let pattern = #"(\d{1,3}(?:[.,]\d{3})*(?:[.,]\d{2})|\d+(?:[.,]\d{2}))"#
        let regex = try? NSRegularExpression(pattern: pattern)
        let ns = text as NSString
        let matches = regex?.matches(in: text, range: NSRange(location: 0, length: ns.length)) ?? []

        return matches.compactMap { m in
            let raw = ns.substring(with: m.range)
            let normalized = normalizeNumberToken(raw)
            return Decimal(string: normalized)
        }
    }

    // Handles: 1,234.56  | 1.234,56 | 1234,56 | 1234.56
    private static func normalizeNumberToken(_ raw: String) -> String {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        let hasDot = s.contains(".")
        let hasComma = s.contains(",")

        if hasDot && hasComma {
            let lastDot = s.lastIndex(of: ".")!
            let lastComma = s.lastIndex(of: ",")!
            if lastDot > lastComma {
                // dot is decimal, commas are thousands
                return s.replacingOccurrences(of: ",", with: "")
            } else {
                // comma is decimal, dots are thousands
                return s.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".")
            }
        }

        if hasComma && !hasDot {
            return s.replacingOccurrences(of: ",", with: ".")
        }

        return s
    }

    private static func parseFirstDate(in text: String) -> Date? {
        if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) {
            let range = NSRange(text.startIndex..., in: text)
            let matches = detector.matches(in: text, options: [], range: range)
            return matches.first?.date
        }
        return nil
    }
}
