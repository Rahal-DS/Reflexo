//
//  LeaderboardsViewModel.swift
//  Reflexo
//
//  Created by Asmiya Hasan on 12/10/2025.
//

import Foundation
import SwiftUI
import FirebaseFirestore


/// Shared view model for all leaderboard screens.
///
/// ### Overview
/// ``LeaderboardViewModel`` fetches the top `HighScore` rows for a given game
/// from Firestore (via ``FirebaseManager``) and exposes simple UI state flags
/// used by all four leaderboard views: Reaction Time, Pattern Recognition,
/// Aim Trainer, and Verbal Memory.
///
/// The model is `@MainActor` so published properties are safe for SwiftUI.
/// Each leaderboard screen provides the `gameName` at initialization and calls
/// ``load(fb:limit:)`` to populate ``topScores``.
///
/// ### Data Model
/// - ``topScores``: The highest‑ranked `HighScore` documents for `gameName`.
/// Ordering is handled by the underlying Firestore query in
/// ``FirebaseManager/getTopScores(game:limit:)`` (typically by ascending
/// `rankScore`).
/// - ``nameByUID``: Optional cache for mapping user IDs to display names (not
/// currently populated by `load`, but available for extensions like lazy
/// profile lookups).
/// - ``isLoading`` / ``errorMessage``: Basic UI state for progress and errors.
///
/// ### Usage
/// ```swift
/// @StateObject private var vm = LeaderboardViewModel(gameName: "ReactionTime")
///
/// .task { await vm.load(fb: firebaseManager) }
/// ```
@MainActor
final class LeaderboardViewModel: ObservableObject {
    // MARK: - Published state
    /// Top leaderboard rows returned from Firestore.
    @Published var topScores: [HighScore] = []
    /// Optional map of user ID → display name for UI convenience.
    @Published var nameByUID: [String: String] = [:]
    /// Loading/progress flag for the UI.
    @Published var isLoading = false
    /// A user‑visible error string when the fetch fails.
    @Published var errorMessage: String?
    
    // MARK: - Configuration
    /// The game identifier whose leaderboard should be loaded (e.g., "ReactionTime").
    private var gameName: String
    
    /// Creates a leaderboard view model for a specific game.
    /// - Parameter gameName: The game whose scores should be fetched.
    init(gameName: String) {
        self.gameName = gameName
    }
    /// Direct Firestore handle (used by helper methods if needed).
    private let db = Firestore.firestore()

    // MARK: - Loading
    /// Loads the top leaderboard rows once from Firestore via ``FirebaseManager``.
    ///
    /// - Parameters:
    /// - fb: The app's Firebase facade used to query scores.
    /// - limit: The maximum number of rows to fetch (default 25).
    ///
    /// On success, assigns ``topScores``; on failure, sets ``errorMessage``.
    func load(fb: FirebaseManager, limit: Int = 25) async {
        isLoading = true
        errorMessage = nil
        do {
            // 1) scores (already ordered ASC for reaction)
            let scores = try await fb.getTopScores(game: gameName, limit: limit)
            self.topScores = scores
        } catch {
            self.errorMessage = "Could not load leaderboard."
        }
        isLoading = false
    }

}
