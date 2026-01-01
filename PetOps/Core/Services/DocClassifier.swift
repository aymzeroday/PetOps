import Foundation

enum DocKind: String {
    case receipt
    case vaccine
    case lab
    case other
}

struct DocClassification {
    let kind: DocKind
    let confidence: Double
    let reason: String
}

enum DocClassifier {
    static func classify(ocr: String) -> DocClassification {
        let t = normalize(ocr)

        // Receipt heuristics
        let receiptHits = score(t, terms: [
            "total", "subtotal", "vat", "tax", "kwd", "kd", "visa", "mastercard", "invoice", "receipt", "cash", "amount"
        ])

        // Vaccine heuristics
        let vaccineHits = score(t, terms: [
            "vaccine", "vaccination", "rabies", "fvr", "feline", "distemper", "parvo", "booster", "microchip", "date of vaccination"
        ])

        // Lab heuristics
        let labHits = score(t, terms: [
            "lab", "laboratory", "cbc", "hematology", "biochemistry", "glucose", "creatinine", "alt", "ast", "result", "reference range"
        ])

        let maxHits = max(receiptHits, vaccineHits, labHits)

        if maxHits == 0 { return .init(kind: .other, confidence: 0.2, reason: "No strong keywords") }

        if maxHits == receiptHits {
            return .init(kind: .receipt, confidence: min(0.95, 0.5 + Double(receiptHits) * 0.08), reason: "Receipt keywords")
        }
        if maxHits == vaccineHits {
            return .init(kind: .vaccine, confidence: min(0.95, 0.5 + Double(vaccineHits) * 0.10), reason: "Vaccine keywords")
        }
        return .init(kind: .lab, confidence: min(0.95, 0.5 + Double(labHits) * 0.10), reason: "Lab keywords")
    }

    private static func score(_ text: String, terms: [String]) -> Int {
        terms.reduce(0) { $0 + (text.contains($1) ? 1 : 0) }
    }

    private static func normalize(_ s: String) -> String {
        s.lowercased()
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
    }
}
