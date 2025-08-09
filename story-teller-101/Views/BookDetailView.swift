import SwiftUI
import SwiftData

struct BookDetailView: View {
    @Environment(\.modelContext) private var modelContext
    
    let book: Book
    
    var body: some View {
        List {
            ForEach(book.chapters.sorted(by: { $0.index < $1.index })) { chapter in
                NavigationLink(destination: ReaderView(chapter: chapter)) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(chapter.title).font(.headline)
                        ProgressView(value: chapter.progress).progressViewStyle(.linear)
                    }
                }
            }
        }
        .navigationTitle(book.title)
    }
}

