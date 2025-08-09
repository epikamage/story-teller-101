import Foundation
import SwiftData

@Model
final class Book {
    @Attribute(.unique)
    var id: UUID
    
    var title: String
    var author: String?
    var language: String?
    var createdAt: Date
    var coverThumb: Data?
    
    // text | pdf | image
    var sourceType: String
    
    @Relationship(deleteRule: .cascade)
    var chapters: [Chapter] = []
    
    @Relationship(deleteRule: .cascade)
    var assets: [ImportAsset] = []
    
    init(
        id: UUID = UUID(),
        title: String,
        author: String? = nil,
        language: String? = nil,
        createdAt: Date = .now,
        coverThumb: Data? = nil,
        sourceType: String
    ) {
        self.id = id
        self.title = title
        self.author = author
        self.language = language
        self.createdAt = createdAt
        self.coverThumb = coverThumb
        self.sourceType = sourceType
    }
}

