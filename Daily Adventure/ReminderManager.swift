//
//  ReminderManager.swift
//  Daily Adventure
//
//  Created by Codex on 09/04/26.
//

import Combine
import Foundation
import UserNotifications

@MainActor
final class ReminderManager: ObservableObject {
    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined

    init() {
        Task {
            await refreshStatus()
        }
    }

    func refreshStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }

    func requestPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
            await refreshStatus()
            return granted
        } catch {
            await refreshStatus()
            return false
        }
    }

    func scheduleDailyReminder(hour: Int, minute: Int) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["daily-adventure-reminder"])

        guard authorizationStatus == .authorized || authorizationStatus == .provisional else {
            return
        }

        var components = DateComponents()
        components.hour = hour
        components.minute = minute

        let content = UNMutableNotificationContent()
        content.title = "Your Daily Adventure is ready"
        content.body = "Take one small walk, keep the streak alive, and get away from the screen."
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: "daily-adventure-reminder", content: content, trigger: trigger)

        try? await center.add(request)
    }
}
