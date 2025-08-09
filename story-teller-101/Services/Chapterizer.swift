import Foundation

struct ChapterCandidate {
    let title: String
    let range: Range<String.Index>
}

struct Chapterizer {
    static func splitIntoChapters(from fullText: String) -> [(title: String, body: String)] {
        let text = fullText
        let pattern = "(?m)^(?:\\n?\\s*)(Chapter\\s+\\d+|Chapter\\s+[IVXLCDM]+|Prologue|Epilogue)\\b[\\n\\r\\t ]*"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return fallbackSegments(text: text)
        }
        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = regex.matches(in: text, options: [], range: nsRange)
        if matches.isEmpty { return fallbackSegments(text: text) }
        var boundaries: [Range<String.Index>] = matches.compactMap { Range($0.range, in: text) }
        boundaries.sort { $0.lowerBound < $1.lowerBound }
        var results: [(String, String)] = []
        for (idx, boundary) in boundaries.enumerated() {
            let start = boundary.lowerBound
            let end = (idx + 1 < boundaries.count) ? boundaries[idx + 1].lowerBound : text.endIndex
            let titleLine = String(text[boundary]).trimmingCharacters(in: .whitespacesAndNewlines)
            let body = String(text[start..<end])
            results.append((titleLine, body))
        }
        if results.isEmpty {
            return fallbackSegments(text: text)
        }
        return results
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

