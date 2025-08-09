import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Book.createdAt, order: .reverse) private var books: [Book]
    
    @State private var isImporterPresented: Bool = false
    @State private var isProcessingImport: Bool = false
    @State private var importErrorMessage: String?
    
    var body: some View {
        NavigationStack {
            Group {
                if books.isEmpty {
                    ContentUnavailableView("Library Empty", systemImage: "books.vertical", description: Text("Import a .txt or .pdf to begin."))
                } else {
                    List {
                        ForEach(books) { book in
                            NavigationLink(value: book) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(book.title).font(.headline)
                                    if let author = book.author, author.isEmpty == false {
                                        Text(author).font(.subheadline).foregroundStyle(.secondary)
                                    }
                                    Text("\(book.chapters.count) chapters").font(.footnote).foregroundStyle(.secondary)
                                }
                            }
                        }
                        .onDelete(perform: deleteBooks)
                    }
                }
            }
            .navigationTitle("Library")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isImporterPresented = true
                    } label: {
                        Label("Import", systemImage: "square.and.arrow.down")
                    }
                }
            }
            .fileImporter(
                isPresented: $isImporterPresented,
                allowedContentTypes: [UTType.plainText, UTType.pdf],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    Task { await handleImport(url: url) }
                case .failure(let error):
                    importErrorMessage = error.localizedDescription
                }
            }
            .navigationDestination(for: Book.self) { book in
                BookDetailView(book: book)
            }
            .overlay(alignment: .bottom) {
                if let message = importErrorMessage {
                    Text(message)
                        .font(.footnote)
                        .padding(8)
                        .background(.thinMaterial, in: Capsule())
                        .padding()
                        .onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 3) { importErrorMessage = nil } }
                }
            }
        }
    }
    
    private func deleteBooks(at offsets: IndexSet) {
        for index in offsets { modelContext.delete(books[index]) }
        try? modelContext.save()
    }
    
    private func handleImport(url: URL) async {
        isProcessingImport = true
        defer { isProcessingImport = false }
        let _ = url.startAccessingSecurityScopedResource()
        defer { url.stopAccessingSecurityScopedResource() }
        do {
            let ext = url.pathExtension.lowercased()
            let fileName = url.deletingPathExtension().lastPathComponent
            var text: String = ""
            if ext == "pdf" {
                text = try PDFParser.extractDocumentText(from: url)
            } else {
                text = (try? String(contentsOf: url)) ?? ""
            }
            guard text.isEmpty == false else { throw NSError(domain: "Import", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unable to read file content"]) }
            let pieces = Chapterizer.splitIntoChapters(from: text)
            let book = Book(title: fileName, sourceType: ext == "pdf" ? "pdf" : "text")
            modelContext.insert(book)
            for (index, piece) in pieces.enumerated() {
                let chapter = Chapter(index: index, title: piece.title, text: piece.body, book: book)
                book.chapters.append(chapter)
            }
            try modelContext.save()
        } catch {
            importErrorMessage = error.localizedDescription
        }
    }
}

