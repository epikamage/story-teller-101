import Foundation
import SwiftData

@Model
final class ImportAsset {
    @Attribute(.unique)
    var id: UUID
    
    var kind: String
    var fileBookmark: Data?
    var pageCount: Int?
    var ocrLanguageHints: [String]?
    var checksum: String?
    
    var book: Book?
    
    init(
        id: UUID = UUID(),
        kind: String,
        fileBookmark: Data? = nil,
        pageCount: Int? = nil,
        ocrLanguageHints: [String]? = nil,
        checksum: String? = nil,
        book: Book? = nil
    ) {
        self.id = id
        self.kind = kind
        self.fileBookmark = fileBookmark
        self.pageCount = pageCount
        self.ocrLanguageHints = ocrLanguageHints
        self.checksum = checksum
        self.book = book
    }
}

