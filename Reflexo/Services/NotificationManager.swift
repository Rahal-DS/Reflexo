//
//  NotificationManager.swift
//  Reflexo
//
//  Created by Asmiya Hasan on 13/10/2025.
//


import UIKit
import UserNotifications

final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()
    private override init() { super.init() }

    // Some friendly lines to rotate through
    private let messages = [
        "Hey! Practice today to increase your reaction time!",
        "Hi! Wanna try to beat the latest Verbal Memory high score?",
        "Quick reflex check? Open Reflexo and play a round!",
        "Your streak misses you — 30 seconds to warm up? 😎",
        "New day, new personal best. Let’s go!"
    ]

    func configure() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self

        // Optional actions (tap actions appear on the notification)
        let playNow = UNNotificationAction(identifier: "PLAY_NOW",
                                           title: "Play now",
                                           options: [.foreground])
        let snooze = UNNotificationAction(identifier: "SNOOZE_15",
                                          title: "Snooze 15 min",
                                          options: [])
        let category = UNNotificationCategory(identifier: "REFLEXO_REMINDER",
                                              actions: [playNow, snooze],
                                              intentIdentifiers: [],
                                              options: [])
        center.setNotificationCategories([category])

        // Ask for permission
        center.requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if let error = error {
                print("Notif permission error:", error)
            } else {
                print("Notif permission granted:", granted)
            }
        }
    }

    // Quick test: fire in X seconds
    func scheduleIn(seconds: TimeInterval) {
        let content = baseContent()
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(5, seconds), repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString,
                                            content: content,
                                            trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    
    // Handle actions (e.g., Snooze)
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        if response.actionIdentifier == "SNOOZE_15" {
            // re-schedule in 15 minutes
            scheduleIn(seconds: 15 * 60)
        }
        completionHandler()
    }

    // Show banners even when app is foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }

    // MARK: - Helpers
    private func baseContent() -> UNNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = "Reflexo Reminder"
        content.body = messages.randomElement() ?? "Time for a quick skill boost!"
        content.sound = .default
        content.categoryIdentifier = "REFLEXO_REMINDER"
        return content
    }
}
