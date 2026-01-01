import Foundation
import PDFKit
import UIKit

enum PDFBuilder {
    static func makePDF(from images: [UIImage]) -> Data? {
        let pdf = PDFDocument()
        for (idx, img) in images.enumerated() {
            if let page = PDFPage(image: img) {
                pdf.insert(page, at: idx)
            }
        }
        return pdf.dataRepresentation()
    }
}
