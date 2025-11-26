//
//  ProfileViewModel.swift
//  Reflexo
//
//  Created by Asmiya Hasan on 12/10/2025.
//
// View model for ``ProfileView`` that loads the signed-in user's profile
/// and computes per-game statistics from local SwiftData.
///
/// `ProfileViewModel` is `@MainActor` to keep all `@Published` updates
/// and UI interactions thread-safe. Remote profile data is fetched via
/// ``FirebaseManager``/Firestore; local statistics are computed using
/// SwiftData queries against your `GameRecord` model.
/// ### Data Sources
/// - **Remote**: Firestore (`/users/{uid}`) via ``FirebaseManager/fetchMyProfile()``
/// - **Local**: SwiftData `GameRecord` entities for stats (top score/accuracy)
///
import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import SwiftData

@MainActor
final class ProfileViewModel: ObservableObject {
    // MARK: - Dependencies

    /// Session facade for lightweight user meta (e.g., display name).
    private var session = UserSessionManager.shared
    
    // MARK: - Published State

    /// The loaded profile document for the current user, or `nil` if not loaded.
    @Published var profile: AppUser?

    /// Indicates whether a load operation is in progress.
    @Published var isLoading = false

    /// A user-presentable error message from the last operation, if any.
    @Published var errorText: String?
    
    private let db = Firestore.firestore()
    
    init() {}
    // MARK: - Lifecycle

    /// Resets the view model to its initial state.
    ///
    /// Clears ``profile``, ``errorText``, and ``isLoading``. Useful when
    /// the user signs out or you need to force a clean reload.
    func reset() {
        profile = nil
        errorText = nil
        isLoading = false
    }
    /// Loads the current user's profile from Firestore.
    ///
    /// Sets ``isLoading`` while the request is in flight, updates ``profile`` on
    /// success, and populates ``errorText`` on failure.
    ///
    /// - Parameters:
    ///   - fb: The ``FirebaseManager`` used to perform the remote fetch.
    ///   - context: The SwiftData `ModelContext`. (Reserved for future use if you
    ///              want to hydrate or cache locally; not required for the fetch.)
    func load(using fb: FirebaseManager, context: ModelContext) {
        guard !isLoading else { return }
        isLoading = true
        errorText = nil
        
        Task {
            defer { isLoading = false }
            do {
                // Profile
                let user = try await fb.fetchMyProfile()
                self.profile = user
            } catch {
                self.errorText = (error as NSError).localizedDescription
            }
        }
    }
    // MARK: - Statistics (SwiftData)

    /// Computes the user's best score for a specific game from local SwiftData.
    ///
    /// Uses a `FetchDescriptor` to select the current user's `GameRecord` rows
    /// for the given `gameName`, ordered by:
    /// 1. Smallest `rankScore` first (better is lower), then
    /// 2. Most recent `attemptedAt`.
    ///
    /// - Parameters:
    ///   - gameName: The canonical game identifier (e.g., `"ReactionTime"`).
    ///   - context: The SwiftData model context used to perform the fetch.
    /// - Returns: The top **score** as `Int`, or `nil` if no attempts exist or
    ///            the user is not signed in.
    /// - Throws: Any SwiftData fetch errors encountered during the query.

    func computeUserTopScore(gameName: String, context: ModelContext) throws -> Int? {
        guard let uid = Auth.auth().currentUser?.uid else { return nil }
        
        var descriptor = FetchDescriptor<GameRecord>(
            predicate: #Predicate { $0.uid == uid && $0.game == gameName },
            sortBy: [
                SortDescriptor(\.rankScore, order: .forward),   // smallest rankScore first
                SortDescriptor(\.attemptedAt, order: .reverse)  // then most recent
            ]
        )
        descriptor.fetchLimit = 1
        
        return try context.fetch(descriptor).first?.score
    }
    /// Computes the user's best accuracy for a specific game from local SwiftData.
    ///
    /// Uses a `FetchDescriptor` to select the current user's `GameRecord` rows
    /// for the given `gameName`, ordered by:
    /// 1. Highest `accuracy` first, then
    /// 2. Most recent `attemptedAt`.
    ///
    /// - Parameters:
    ///   - gameName: The canonical game identifier (e.g., `"AimTrainer"`).
    ///   - context: The SwiftData model context used to perform the fetch.
    /// - Returns: The best **accuracy** as `Float`, or `nil` if no attempts exist
    ///            or the user is not signed in.
    /// - Throws: Any SwiftData fetch errors encountered during the query.
    func computeUserTopAccuracy(gameName: String, context: ModelContext) throws -> Float? {
        guard let uid = Auth.auth().currentUser?.uid else { return nil }
        
        var descriptor = FetchDescriptor<GameRecord>(
            predicate: #Predicate { $0.uid == uid && $0.game == gameName },
            sortBy: [
                SortDescriptor(\.accuracy, order: .reverse),   // highest accuraacy first
                SortDescriptor(\.attemptedAt, order: .reverse)  // then most recent
            ]
        )
        descriptor.fetchLimit = 1
        
        return try context.fetch(descriptor).first?.accuracy
    }
}
