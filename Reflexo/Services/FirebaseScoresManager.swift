//
//  FirebaseScoresManager.swift
//  Reflexo
//
//  Created by Asmiya Hasan on 13/10/2025.
//

import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore

/// A Firestore-backed service that saves and queries high scores for Reflexo.
///
/// `FirebaseScoresManager` is a `@MainActor` `ObservableObject` singleton that:
/// - Saves a user's best score per game using a deterministic document ID (`{uid}_{game}`).
/// - Returns the top *N* scores for a game ordered by `rankScore` (lower is better).
/// - Returns the current user's best score for a specific game.
///
/// ### Requirements
/// - Firestore Rules must permit the authenticated user to read/write to `scores/{uid_game}`
///   and read `users/{uid}` to obtain `displayName`.
/// - The `users/{uid}` document must decode to `AppUser`.
/// - A composite index may be required for `scores` on `game` (filter) + `rankScore` (order).
///   Create it if Firestore prompts you.
///
/// ### Threading
/// This type is `@MainActor` because UI code often observes it. All async calls hop to
/// background threads as needed by Firebase SDK.

@MainActor
final class FirebaseScoresManager: ObservableObject {
    
    /// Shared instance for app-wide use.
    static let shared = FirebaseScoresManager()
    
    private init() {}
    
    /// The current Firebase Auth user (mirrors `Auth.auth().currentUser` at initialization time).
    @Published var currentUser: User? = Auth.auth().currentUser
    
    /// Firestore database handle.
    private let db = Firestore.firestore()

    // MARK: - Save a high score
    /// Saves (or updates) the user's best high score for a game.
    ///
    /// This method uses a Firestore **transaction** and a stable document ID
    /// of the form `"{uid}_{game}"` to ensure one best-score doc per user/game.
    /// If the document exists, it will only update when the incoming `rankScore`
    /// is **better** (numerically smaller) than the current value.
    ///
    /// - Parameters:
    ///   - game: The game identifier (e.g., `"ReactionTime"`).
    ///   - score: The raw score value to display (e.g., milliseconds for reaction time).
    ///   - rankScore: The value used for leaderboard ordering. **Lower is better.**
    ///   - accuracy: An optional accuracy metric to display alongside the score.
    ///
    /// - Throws:
    ///   - ``AuthError/notSignedIn`` if no authenticated user is present.
    ///   - Any error thrown by Firestore reads/writes or decoding `AppUser`.
    ///
    /// - Important: This call reads the user's `displayName` from `users/{uid}` and stores
    ///   it  in the `scores` document for faster leaderboard queries.
    func saveHighScore(game: String, score: Int, rankScore: Int, accuracy: Int) async throws {
        guard let uid = Auth.auth().currentUser?.uid else { throw AuthError.notSignedIn }
        let displayName = try await db.collection("users").document(uid).getDocument(as: AppUser.self).displayName
        
            let docId = "\(uid)_\(game)"
            let ref = db.collection("scores").document(docId)

            try await db.runTransaction { txn, _ in
                let snap = try? txn.getDocument(ref)

                if let snap, snap.exists {
                    let data = snap.data() ?? [:]
                    let currentBest = data["rankScore"] as? Int ?? Int.max
                    guard rankScore < currentBest else { return nil }

                    txn.updateData([
                        "score": score,
                        "rankScore": rankScore,
                        "accuracy": accuracy,
                        "updatedAt": FieldValue.serverTimestamp()
                    ], forDocument: ref)
                } else {
                    txn.setData([
                        "uid": uid,
                        "displayName": displayName,
                        "game": game,
                        "score": score,
                        "rankScore": rankScore,
                        "accuracy": accuracy,
                        "createdAt": FieldValue.serverTimestamp(),
                        "updatedAt": FieldValue.serverTimestamp()
                    ], forDocument: ref)
                }
                return nil
            }
    }
    
    // MARK: - Leaderboard (top N fastest)
    /// Fetches the top `limit` scores for a game ordered by `rankScore` ascending.
    ///
    /// - Parameters:
    ///   - game: The game identifier.
    ///   - limit: Maximum number of results to return. Defaults to `25`.
    ///
    /// - Returns: An array of ``HighScore`` documents sorted by best `rankScore` first.
    ///
    /// - Throws: Any Firestore error or decoding error.
    ///
    /// - Important:
    ///   This query filters on `game` and orders by `rankScore`, which commonly requires
    ///   a **composite index** in Firestore. If you see an error with a console link,
    ///   follow it to create the suggested index.
    func getTopScores(game: String, limit: Int = 25) async throws -> [HighScore] {
        let q = db.collection("scores")
        .whereField("game", isEqualTo: game)
        .order(by: "rankScore", descending: false) // smaller is better
        .limit(to: limit)
        let snap = try await q.getDocuments()
        return snap.documents.compactMap { try? $0.data(as: HighScore.self) }
    }
    
    // MARK: - My best score
    /// Returns the current user's saved best score for the specified game, if any.
    ///
    /// - Parameter game: The game identifier.
    /// - Returns: The user's ``HighScore`` for this game, or `nil` if none exists.
    /// - Throws:
    ///   - ``AuthError/notSignedIn`` if no authenticated user is present.
    ///   - Any Firestore error or decoding error.
    ///
    /// - Note:
    ///   This performs a simple equality query on `uid` + `game`. Because it does **not**
    ///   use `order(by:)`, it requires a composite index.
    func getMyBestScore(game: String) async throws -> HighScore? {
        guard let uid = Auth.auth().currentUser?.uid else { throw AuthError.notSignedIn }
        let q = db.collection("scores")
        .whereField("game", isEqualTo: game)
        .whereField("uid", isEqualTo: uid)
        let snap = try await q.getDocuments()
        return snap.documents.first.flatMap { try? $0.data(as: HighScore.self) }
    }

}
