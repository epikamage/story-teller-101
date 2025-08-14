import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Book.createdAt, order: .reverse) private var books: [Book]
    
    @State private var isImporterPresented: Bool = false
    @State private var isProcessingImport: Bool = false
    @State private var importErrorMessage: String?
    @State private var importSuccessMessage: String?
    @State private var bookToDelete: Book?
    @State private var showDeleteBookAlert = false
    
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
                            .contextMenu {
                                Button(role: .destructive) {
                                    bookToDelete = book
                                    showDeleteBookAlert = true
                                } label: {
                                    Label("Delete Book", systemImage: "trash")
                                }
                            }
                        }
                        .onDelete(perform: { offsets in
                            if let index = offsets.first {
                                bookToDelete = books[index]
                                showDeleteBookAlert = true
                            }
                        })
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
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink(destination: SettingsView()) {
                        Image(systemName: "gear")
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
                        .foregroundColor(.red)
                        .padding(8)
                        .background(.thinMaterial, in: Capsule())
                        .padding()
                        .onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 3) { importErrorMessage = nil } }
                }
                if let message = importSuccessMessage {
                    Text(message)
                        .font(.footnote)
                        .foregroundColor(.green)
                        .padding(8)
                        .background(.thinMaterial, in: Capsule())
                        .padding()
                        .onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 3) { importSuccessMessage = nil } }
                }
            }
            .alert("Delete Book", isPresented: $showDeleteBookAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    if let book = bookToDelete {
                        deleteBook(book)
                    }
                }
            } message: {
                if let book = bookToDelete {
                    Text("Are you sure you want to delete '\(book.title)'? This will also delete all \(book.chapters.count) chapters. This action cannot be undone.")
                }
            }
        }
    }
    
    private func deleteBooks(at offsets: IndexSet) {
        for index in offsets { modelContext.delete(books[index]) }
        try? modelContext.save()
    }
    
    private func deleteBook(_ book: Book) {
        // Delete the book (chapters will be automatically deleted due to cascade rule)
        modelContext.delete(book)
        
        // Save changes
        try? modelContext.save()
        
        // Show success message
        importSuccessMessage = "Book '\(book.title)' deleted successfully"
        
        // Reset the book to delete
        bookToDelete = nil
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
            var filteredPages: Int = 0
            
            if ext == "pdf" {
                // Use enhanced PDF parsing for better content analysis
                let (fullText, pages) = try PDFParser.extractDocumentTextWithPages(from: url)
                text = fullText
                
                // Count pages that were identified as index/glossary
                filteredPages = pages.filter { $0.isLikelyIndex || $0.isLikelyGlossary }.count
            } else {
                text = (try? String(contentsOf: url)) ?? ""
            }
            
            guard text.isEmpty == false else { 
                throw NSError(domain: "Import", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unable to read file content"]) 
            }
            
            let pieces = Chapterizer.splitIntoChapters(from: text)
            let book = Book(title: fileName, sourceType: ext == "pdf" ? "pdf" : "text")
            modelContext.insert(book)
            
            for (index, piece) in pieces.enumerated() {
                let chapter = Chapter(index: index, title: piece.title, text: piece.body, book: book)
                book.chapters.append(chapter)
            }
            
            try modelContext.save()
            
            // Show success message with filtering info
            if ext == "pdf" && filteredPages > 0 {
                importSuccessMessage = "Imported successfully! Filtered out \(filteredPages) index/glossary pages. Created \(pieces.count) chapters."
            } else {
                importSuccessMessage = "Imported successfully! Created \(pieces.count) chapters."
            }
            
        } catch {
            importErrorMessage = error.localizedDescription
        }
    }
}

