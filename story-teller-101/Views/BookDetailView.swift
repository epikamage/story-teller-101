import SwiftUI
import SwiftData

struct BookDetailView: View {
    @Environment(\.modelContext) private var modelContext
    
    let book: Book
    
    @State private var chapterToDelete: Chapter?
    @State private var showDeleteAlert = false
    @State private var isBulkDelete = false
    @State private var successMessage: String?
    
    var body: some View {
        Group {
            if book.chapters.isEmpty {
                ContentUnavailableView("No Chapters", systemImage: "text.book.closed", description: Text("This book has no chapters. Import a document to get started."))
            } else {
                List {
                    ForEach(book.chapters.sorted(by: { $0.index < $1.index })) { chapter in
                        NavigationLink(destination: ReaderView(chapter: chapter)) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(chapter.title).font(.headline)
                                ProgressView(value: chapter.progress).progressViewStyle(.linear)
                            }
                        }
                        .contextMenu {
                            Button(role: .destructive) {
                                chapterToDelete = chapter
                                isBulkDelete = false
                                showDeleteAlert = true
                            } label: {
                                Label("Delete Chapter", systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                chapterToDelete = chapter
                                isBulkDelete = false
                                showDeleteAlert = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                    .onDelete(perform: deleteChapters)
                }
            }
        }
        .navigationTitle(book.title)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if !book.chapters.isEmpty {
                    Menu {
                        Button(role: .destructive) {
                            // Show bulk delete confirmation
                            isBulkDelete = true
                            showDeleteAlert = true
                        } label: {
                            Label("Delete All Chapters", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .alert(isBulkDelete ? "Delete All Chapters" : "Delete Chapter", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) { 
                isBulkDelete = false
                chapterToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if isBulkDelete {
                    deleteAllChapters()
                } else if let chapter = chapterToDelete {
                    deleteChapter(chapter)
                }
                isBulkDelete = false
                chapterToDelete = nil
            }
        } message: {
            if isBulkDelete {
                Text("Are you sure you want to delete all \(book.chapters.count) chapters? This action cannot be undone.")
            } else if let chapter = chapterToDelete {
                Text("Are you sure you want to delete '\(chapter.title)'? This action cannot be undone.")
            }
        }
        .overlay(alignment: .bottom) {
            if let message = successMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundColor(.green)
                    .padding(8)
                    .background(.thinMaterial, in: Capsule())
                    .padding()
                    .onAppear { 
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { 
                            successMessage = nil 
                        } 
                    }
            }
        }
    }
    
    private func deleteChapters(at offsets: IndexSet) {
        let sortedChapters = book.chapters.sorted(by: { $0.index < $1.index })
        for index in offsets {
            let chapter = sortedChapters[index]
            deleteChapter(chapter)
        }
    }
    
    private func deleteChapter(_ chapter: Chapter) {
        // Remove chapter from book's chapters array
        if let index = book.chapters.firstIndex(where: { $0.id == chapter.id }) {
            book.chapters.remove(at: index)
        }
        
        // Delete the chapter from the model context
        modelContext.delete(chapter)
        
        // Reindex remaining chapters
        reindexChapters()
        
        // Save changes
        try? modelContext.save()
        successMessage = "Chapter '\(chapter.title)' deleted."
    }
    
    private func reindexChapters() {
        let sortedChapters = book.chapters.sorted(by: { $0.index < $1.index })
        for (newIndex, chapter) in sortedChapters.enumerated() {
            chapter.index = newIndex
        }
    }
    
    private func deleteAllChapters() {
        let chapterCount = book.chapters.count
        
        // Delete all chapters from the model context
        for chapter in book.chapters {
            modelContext.delete(chapter)
        }
        
        // Clear the chapters array
        book.chapters.removeAll()
        
        // Save changes
        try? modelContext.save()
        
        successMessage = "All \(chapterCount) chapters deleted."
    }
}

