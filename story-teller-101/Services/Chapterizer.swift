import Foundation

struct ChapterCandidate {
    let title: String
    let range: Range<String.Index>
}

struct Chapterizer {
    // Keywords that indicate non-chapter content
    private static let nonChapterKeywords = [
        "index", "glossary", "bibliography", "references", "appendix", "appendices",
        "table of contents", "contents", "acknowledgments", "acknowledgements",
        "preface", "foreword", "introduction", "conclusion", "notes", "credits"
    ]
    
    static func splitIntoChapters(from fullText: String) -> [(title: String, body: String)] {
        let text = fullText
        
        // Enhanced pattern to catch more chapter-like headings
        let pattern = "(?m)^(?:\\n?\\s*)((?:Chapter\\s+\\d+|Chapter\\s+[IVXLCDM]+|Prologue|Epilogue|Part\\s+\\d+|Section\\s+\\d+|Book\\s+\\d+|Act\\s+\\d+|Scene\\s+\\d+|Canto\\s+\\d+|Stanza\\s+\\d+)\\b[\\n\\r\\t ]*)"
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return fallbackSegments(text: text)
        }
        
        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = regex.matches(in: text, options: [], range: nsRange)
        
        if matches.isEmpty { 
            return fallbackSegments(text: text) 
        }
        
        var boundaries: [Range<String.Index>] = matches.compactMap { Range($0.range, in: text) }
        boundaries.sort { $0.lowerBound < $1.lowerBound }
        
        var results: [(String, String)] = []
        
        for (idx, boundary) in boundaries.enumerated() {
            let start = boundary.lowerBound
            let end = (idx + 1 < boundaries.count) ? boundaries[idx + 1].lowerBound : text.endIndex
            let titleLine = String(text[boundary]).trimmingCharacters(in: .whitespacesAndNewlines)
            let body = String(text[start..<end])
            
            // Filter out non-chapter content
            if !isNonChapterContent(title: titleLine, body: body) {
                results.append((titleLine, body))
            }
        }
        
        if results.isEmpty {
            return fallbackSegments(text: text)
        }
        
        return results
    }
    
    // Check if the content should be excluded from chapters
    private static func isNonChapterContent(title: String, body: String) -> Bool {
        let titleLower = title.lowercased()
        let bodyLower = body.lowercased()
        
        // Check title for non-chapter keywords
        for keyword in nonChapterKeywords {
            if titleLower.contains(keyword) {
                return true
            }
        }
        
        // Check if the body content is primarily index/glossary material
        // Look for patterns like "A... 123", "B... 456" which are typical of indexes
        let indexPattern = "\\b[A-Z]\\s*\\.{3,}\\s*\\d+"
        if let regex = try? NSRegularExpression(pattern: indexPattern, options: []) {
            let nsRange = NSRange(bodyLower.startIndex..<bodyLower.endIndex, in: bodyLower)
            let matches = regex.matches(in: bodyLower, options: [], range: nsRange)
            
            // If more than 30% of lines match index pattern, consider it non-chapter
            let lines = body.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            if !lines.isEmpty && matches.count > lines.count * Int(0.3) {
                return true
            }
        }
        
        // Check for glossary patterns (word - definition)
        let glossaryPattern = "\\b\\w+\\s*[-–—]\\s*[A-Z]"
        if let regex = try? NSRegularExpression(pattern: glossaryPattern, options: []) {
            let nsRange = NSRange(bodyLower.startIndex..<bodyLower.endIndex, in: bodyLower)
            let matches = regex.matches(in: bodyLower, options: [], range: nsRange)
            
            let lines = body.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            if !lines.isEmpty && matches.count > lines.count * Int(0.4) {
                return true
            }
        }
        
        // Check for bibliography patterns (Author, Year. Title)
        let bibliographyPattern = "\\b[A-Z][a-z]+,\\s*\\d{4}\\.\\s*[A-Z]"
        if let regex = try? NSRegularExpression(pattern: bibliographyPattern, options: []) {
            let nsRange = NSRange(bodyLower.startIndex..<bodyLower.endIndex, in: bodyLower)
            let matches = regex.matches(in: bodyLower, options: [], range: nsRange)
            
            let lines = body.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            if !lines.isEmpty && matches.count > lines.count * Int(0.3) {
                return true
            }
        }
        
        // Check for table of contents patterns
        let tocPattern = "\\b\\d+\\s*\\.\\s*[A-Z][^\\n]*\\s*\\.{3,}\\s*\\d+"
        if let regex = try? NSRegularExpression(pattern: tocPattern, options: []) {
            let nsRange = NSRange(bodyLower.startIndex..<bodyLower.endIndex, in: bodyLower)
            let matches = regex.matches(in: bodyLower, options: [], range: nsRange)
            
            let lines = body.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            if !lines.isEmpty && matches.count > lines.count * Int(0.4) {
                return true
            }
        }
        
        // Check if content is too short to be a meaningful chapter (likely a header page)
        if body.trimmingCharacters(in: .whitespacesAndNewlines).count < 100 {
            return true
        }
        
        return false
    }
    
    private static func fallbackSegments(text: String) -> [(title: String, body: String)] {
        let windowSize = 4000
        var segments: [(String, String)] = []
        var startIndex = text.startIndex
        var chapterNumber = 1
        while startIndex < text.endIndex {
            let endIndex = text.index(startIndex, offsetBy: windowSize, limitedBy: text.endIndex) ?? text.endIndex
            let body = String(text[startIndex..<endIndex])
            segments.append(("Chapter \(chapterNumber)", body))
            chapterNumber += 1
            startIndex = endIndex
        }
        return segments
    }
}

