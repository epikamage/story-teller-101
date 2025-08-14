import Foundation
import PDFKit

enum PDFParserError: Error {
    case invalidDocument
}

struct PDFPage {
    let pageNumber: Int
    let text: String
    let isLikelyIndex: Bool
    let isLikelyGlossary: Bool
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
    
    // Enhanced method to extract text with page-level analysis
    static func extractDocumentTextWithPages(from url: URL) throws -> (fullText: String, pages: [PDFPage]) {
        guard let document = PDFDocument(url: url) else { throw PDFParserError.invalidDocument }
        
        var fullText = ""
        var pages: [PDFPage] = []
        
        for pageIndex in 0..<(document.pageCount) {
            if let page = document.page(at: pageIndex) {
                let pageText = page.string ?? ""
                fullText.append(pageText)
                fullText.append("\n")
                
                // Analyze page content for index/glossary patterns
                let isIndex = analyzePageForIndexPatterns(pageText)
                let isGlossary = analyzePageForGlossaryPatterns(pageText)
                
                pages.append(PDFPage(
                    pageNumber: pageIndex + 1,
                    text: pageText,
                    isLikelyIndex: isIndex,
                    isLikelyGlossary: isGlossary
                ))
            }
        }
        
        return (fullText, pages)
    }
    
    // Analyze if a page contains index-like patterns
    private static func analyzePageForIndexPatterns(_ text: String) -> Bool {
        let indexPatterns = [
            "\\b[A-Z]\\s*\\.{3,}\\s*\\d+",           // A... 123
            "\\b[A-Z][a-z]+\\s*\\.{3,}\\s*\\d+",     // Apple... 123
            "\\b\\w+\\s*\\.{3,}\\s*\\d+"             // word... 123
        ]
        
        for pattern in indexPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
                let matches = regex.matches(in: text, options: [], range: nsRange)
                
                let lines = text.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                if !lines.isEmpty && matches.count > lines.count * Int(0.3) {
                    return true
                }
            }
        }
        
        return false
    }
    
    // Analyze if a page contains glossary-like patterns
    private static func analyzePageForGlossaryPatterns(_ text: String) -> Bool {
        let glossaryPatterns = [
            "\\b\\w+\\s*[-–—]\\s*[A-Z]",              // word - Definition
            "\\b\\w+\\s*:\\s*[A-Z]",                   // word: Definition
            "\\b\\w+\\s*\\.\\s*[A-Z]"                  // word. Definition
        ]
        
        for pattern in glossaryPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
                let matches = regex.matches(in: text, options: [], range: nsRange)
                
                let lines = text.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                if !lines.isEmpty && matches.count > lines.count * Int(0.4) {
                    return true
                }
            }
        }
        
        return false
    }
}

