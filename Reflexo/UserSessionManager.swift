//
//  UserSessionManager.swift
//  Reflexo
//
//  Created by Asmiya Hasan on 13/10/2025.
//

// UserSessionManager.swift
import SwiftUI
import Combine
import FirebaseAuth
import FirebaseFirestore

/// Centralized session controller for Firebase auth state and the
/// corresponding user profile document (`/users/{uid}`).
///
/// `UserSessionManager`:
/// - Listens for FirebaseAuth state changes and exposes the raw `User` in ``authUser``.
/// - Attaches a Firestore snapshot listener to `/users/{uid}` and decodes it into ``profile``.
/// - Provides convenient, user-friendly accessors like ``displayName`` and ``email``.
/// - Runs on the main actor so UI bindings remain thread-safe.
///
/// Use ``start()`` **once at app launch** (e.g., in `App` or a root view
/// like `ContentView.onAppear`) and ``stop()`` when tearing down or on sign-out
/// if you need to fully reset listeners.
///
////// ### Data Flow
/// 1. ``start()`` registers a FirebaseAuth listener → updates ``authUser``
/// 2. For non-nil user, ``attachProfileListener(for:)`` subscribes to `/users/{uid}`
/// 3. Firestore snapshot updates → decode to ``profile``
///
@MainActor
final class UserSessionManager: ObservableObject {
    // MARK: - Singleton

    /// Shared singleton instance.
    static let shared = UserSessionManager()
    private init() {}

    // MARK: - Published State

    /// The raw Firebase authenticated user (`FirebaseAuth.User`), or `nil` if signed out.
    @Published private(set) var authUser: User?

    /// The app's profile model loaded from `/users/{uid}`, or `nil` until available.
    @Published private(set) var profile: AppUser?

    // MARK: - Convenient Accessors

    /// The current user ID string (from FirebaseAuth) or `"local-user"` for offline/testing.
    ///
    /// > Note: Consider making this a non-optional `String` in future refactors since
    /// > a fallback is always returned.
    var uid: String? { authUser?.uid ?? "local-user"}
    var displayName: String {
        profile?.displayName
        ?? (authUser?.displayName?.isEmpty == false ? authUser!.displayName! : nil)
        ?? authUser?.email
        ?? "Anonymous"
    }
    
    var email: String {
        profile?.email
        ?? (authUser?.email?.isEmpty == false ? authUser!.email! : nil)
        ?? authUser?.email
        ?? "Anonymous"
    }
    
    /// `true` when an authenticated Firebase user is present.
    var isSignedIn: Bool { authUser != nil }

    // internals
    private let db = Firestore.firestore()
    private var authHandle: AuthStateDidChangeListenerHandle?
    private var profileListener: ListenerRegistration?

    // MARK: - Lifecycle

      /// Starts observing Firebase authentication and the current user's profile document.
      ///
      /// Call this **once** during app startup. Subsequent calls will reset existing listeners.
    func start() {
        stop()
        authHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.authUser = user
                self?.attachProfileListener(for: user?.uid)
            }
        }
    }

    /// Stops all listeners and clears the in-memory session state.
    ///
    /// Useful when signing out or disposing of the session manager.
    func stop() {
        if let h = authHandle { Auth.auth().removeStateDidChangeListener(h) }
        authHandle = nil
        profileListener?.remove()
        profileListener = nil
        authUser = nil
        profile = nil
    }
    // MARK: - Profile Listener

    /// Attaches a Firestore snapshot listener to `/users/{uid}` and decodes it into ``profile``.
    ///
    /// Removes any existing listener before attaching a new one. If `uid` is `nil`,
    /// the method clears the current profile and returns.
    ///
    /// - Parameter uid: The Firebase user ID whose profile to observe.
    private func attachProfileListener(for uid: String?) {
        profileListener?.remove();
        profileListener = nil
        profile = nil
        guard let uid else { return }
        profileListener = db.collection("users").document(uid)
            .addSnapshotListener { [weak self] snap, _ in
                Task { @MainActor in
                    self?.profile = try? snap?.data(as: AppUser.self)
                }
            }
    }
}
