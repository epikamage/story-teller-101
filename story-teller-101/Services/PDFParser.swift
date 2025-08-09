import Foundation
import PDFKit

enum PDFParserError: Error {
    case invalidDocument
}

struct PDFParser {
    static func extractDocumentText(from url: URL) throws -> String {
        guard let document = PDFDocument(url: url) else { throw PDFParserError.invalidDocument }
        if let fullText = document.string, fullText.isEmpty == false {
            return fullText
        }
        var all = ""
        for pageIndex in 0..<(document.pageCount) {
            if let page = document.page(at: pageIndex) {
                all.append(page.string ?? "")
                all.append("\n")
            }
        }
        return all
    }
}

