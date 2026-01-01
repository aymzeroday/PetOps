import Foundation
import Vision
import UIKit

final class OCRService {
    static let shared = OCRService()
    private init() {}

    func recognizeText(from images: [UIImage]) async throws -> String {
        var all: [String] = []

        for img in images {
            guard let cg = img.cgImage else { continue }
            let handler = VNImageRequestHandler(cgImage: cg, options: [:])

            let request = VNRecognizeTextRequest { req, _ in
                let lines = (req.results as? [VNRecognizedTextObservation])?
                    .compactMap { $0.topCandidates(1).first?.string } ?? []
                all.append(contentsOf: lines)
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            try handler.perform([request])
        }

        return all.joined(separator: "\n")
    }
}
