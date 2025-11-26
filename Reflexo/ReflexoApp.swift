//
//  ReflexoApp.swift
//  Reflexo
//
//  Created by Rahal De Silva on 30/8/2025.
//

import SwiftUI
import FirebaseCore
import SwiftData

/// The SwiftUI application entry point for **Reflexo**.
///
/// `ReflexoApp` wires up core services and environment objects:
/// - Configures Firebase via a UIKit ``AppDelegate`` bridge.
/// - Configures local notifications with ``NotificationManager``.
/// - Injects shared managers (``FirebaseManager``, ``FirebaseScoresManager``,
///   ``UserSessionManager``) into the environment.
/// - Starts the user session listener on launch.
/// - Provides a SwiftData model container for ``GameRecord``.
///
/// ### Architecture
/// - **UIKit bridge**: An ``AppDelegate`` is used solely to call `FirebaseApp.configure()`
///   and set up notifications early in app launch.
/// - **State management**: Uses `@StateObject` singletons to avoid duplicate instances
///   and to expose managers to the entire view hierarchy.
/// - **Persistence**: Declares a `modelContainer` for the `GameRecord` model used by
///   game stats and offline caching.
///
/// ### Usage
/// The app launches into ``ContentView`` which performs route selection and
/// renders the appropriate screen.


@main
struct ReflexoApp: App {
    // MARK: - Shared Managers (Environment)
    
    /// Firebase facade (auth, Firestore helpers).
    @StateObject private var fb = FirebaseManager.shared
    
    // MARK: - Shared Managers (Environment)
    
    /// Firebase facade (auth, Firestore helpers).
    @StateObject private var fbScores = FirebaseScoresManager.shared
    
    /// Centralized session state (auth user + `/users/{uid}` profile listener).
    @StateObject private var session = UserSessionManager.shared
    
    // MARK: - UIKit App Delegate
    
    /// Bridges to UIKit for Firebase configuration and notification setup.
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    // MARK: - Scene
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(fb)
                .environmentObject(fbScores)
                .environmentObject(session)
            
            // Start observing auth/profile changes after the root view appears.
                .task { session.start() }
        }
        .modelContainer(for: [GameRecord.self])
    }
}
/// A lightweight UIKit delegate used to configure framework services
/// that require `UIApplicationDelegate` hooks (Firebase, notifications).
///
/// - Configures Firebase as early as possible in the app lifecycle.
/// - Delegates notification authorization/category setup to
///   ``NotificationManager``.
class AppDelegate: NSObject, UIApplicationDelegate {
    
    /// Called after the app has launched. Initializes Firebase and notifications.
    ///
    /// - Parameters:
    ///   - application: The singleton app object.
    ///   - launchOptions: Launch options from the system (unused).
    /// - Returns: `true` to indicate successful launch.
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseApp.configure()
        NotificationManager.shared.configure()
        return true
    }
}
