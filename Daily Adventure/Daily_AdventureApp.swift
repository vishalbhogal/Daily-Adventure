//
//  Daily_AdventureApp.swift
//  Daily Adventure
//
//  Created by Vishal Bhogal on 09/04/26.
//

import SwiftUI
import SwiftData

@main
struct Daily_AdventureApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            DailyChallenge.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
