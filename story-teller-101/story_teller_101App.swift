//
//  story_teller_101App.swift
//  story-teller-101
//
//  Created by Peeyush Karnwal on 09/08/25.
//

import SwiftUI
import SwiftData

@main
struct story_teller_101App: App {
    var body: some Scene {
        WindowGroup {
            LibraryView()
                .modelContainer(for: [Book.self, Chapter.self, VoiceProfile.self, ImportAsset.self])
        }
    }
}
