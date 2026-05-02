//
//  MainTabBarController.swift
//  Daily Adventure
//
//  Created by Vishal Bhogal on 09/04/26.
//

import UIKit
import SwiftData
import SwiftUI

class MainTabBarController: UITabBarController {
    
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupTabs()
        setupAppearance()
    }
    
    private func setupTabs() {
        // 1. Today (SwiftUI Bridge)
        // Note: For a real Lead role, you'd explain that you're keeping this as SwiftUI 
        // because it contains complex Sci-Fi animations that are highly efficient in SwiftUI.
        let todayVC = UIHostingController(rootView: TodayTabViewBridge(modelContext: modelContext))
        todayVC.tabBarItem = UITabBarItem(title: "Today", image: UIImage(systemName: "figure.walk.circle.fill"), tag: 0)
        
        // 2. History (Pure UIKit)
        // This is your flagship screen to show the CTO.
        let historyVC = UINavigationController(rootViewController: HistoryViewController(modelContext: modelContext))
        historyVC.tabBarItem = UITabBarItem(title: "History", image: UIImage(systemName: "clock.arrow.trianglehead.counterclockwise.rotate.90"), tag: 1)
        
        // 3. Profile (SwiftUI Bridge)
        let profileVC = UIHostingController(rootView: ProfileTabViewBridge(modelContext: modelContext))
        profileVC.tabBarItem = UITabBarItem(title: "Profile", image: UIImage(systemName: "person.fill"), tag: 2)
        
        // 4. Settings (SwiftUI Bridge)
        let settingsVC = UIHostingController(rootView: SettingsTabViewBridge(modelContext: modelContext))
        settingsVC.tabBarItem = UITabBarItem(title: "Settings", image: UIImage(systemName: "slider.horizontal.3"), tag: 3)
        
        viewControllers = [todayVC, historyVC, profileVC, settingsVC]
    }
    
    private func setupAppearance() {
        tabBar.tintColor = .label
        tabBar.unselectedItemTintColor = .secondaryLabel
    }
}

// MARK: - SwiftUI Bridges
// These allow us to keep the complex SwiftUI content while migrating the "Shell" to UIKit.

struct TodayTabViewBridge: View {
    let modelContext: ModelContext
    
    // Logic from original ContentView to manage Today's state
    @StateObject private var locationManager = LocationManager()
    @State private var preferredRadiusMeters = 1000.0
    private let generator = ChallengeGenerator()
    
    var body: some View {
        TodayTab(
            allChallenges: [], // Query handles this inside TodayTab if passed correctly, or we need to pass the context
            locationManager: locationManager,
            preferredRadiusMeters: preferredRadiusMeters,
            generator: generator
        )
        .modelContext(modelContext)
        .onAppear {
            locationManager.refreshLocation()
        }
    }
}

struct ProfileTabViewBridge: View {
    let modelContext: ModelContext
    @Query private var allChallenges: [DailyChallenge]
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        _allChallenges = Query(sort: \DailyChallenge.createdAt, order: .reverse)
    }
    
    var body: some View {
        ProfileTab(allChallenges: allChallenges) {
            // Sign out logic
            print("Sign out")
        }
        .modelContext(modelContext)
    }
}

struct SettingsTabViewBridge: View {
    let modelContext: ModelContext
    
    @StateObject private var reminderManager = ReminderManager()
    @AppStorage("preferredRadiusMeters") private var preferredRadiusMeters = 1_000.0
    @AppStorage("dailyReminderHour") private var dailyReminderHour = 18
    @AppStorage("dailyReminderMinute") private var dailyReminderMinute = 15
    @AppStorage("remindersEnabled") private var remindersEnabled = false
    
    var body: some View {
        SettingsTab(
            preferredRadiusMeters: .init(get: { preferredRadiusMeters }, set: { preferredRadiusMeters = $0 }),
            dailyReminderHour: .init(get: { dailyReminderHour }, set: { dailyReminderHour = $0 }),
            dailyReminderMinute: .init(get: { dailyReminderMinute }, set: { dailyReminderMinute = $0 }),
            remindersEnabled: .init(get: { remindersEnabled }, set: { remindersEnabled = $0 }),
            reminderManager: reminderManager
        )
        .modelContext(modelContext)
    }
}
