//
//  HighScore.swift
//  Reflexo
//
//  Created by Asmiya Hasan on 11/10/2025.
//

import SwiftUI
import FirebaseFirestore

/// A single game result recorded for a player.
///
/// Scores for *all* Reflexo games live in one collection (e.g. `scores`) and
/// share this schema. Use ``rankScore`` so leaderboards can sort consistently
/// (lower is always better), even when raw scoring differs per game.
///
/// - Important: For games where “higher is better” (e.g.,verbal memory),
///   convert to a *lower-is-better* ``rankScore`` (e.g., `rankScore = - score`).
///   For “lower is better” games, set `rankScore = score`.
struct HighScore: Codable, Identifiable {
    /// Firestore document identifier.
    @DocumentID var id: String?
    /// The player’s Firebase Auth UID.
    /// Use this to fetch a user’s personal bests or to filter by owner.
    let uid: String
    
    /// The player's unique display name
    let displayName: String
    
    /// Game identifier (e.g., `"ReactionTime"`, `"VerbalMemory"`, `"AimTrainer"`, `"SequenceTest"`).
    let game: String
    
    /// The raw game score as displayed to the player.
    ///
    /// - Example: reaction time in milliseconds, number of words remembered, etc.
    var score: Int
    
    /// Normalized score for ranking where **lower is always better**.
    ///
    /// - Example: For reaction time (lower is better), set `rankScore = score`.
    /// - Example: For memory games (higher is better), set `rankScore = -score`.
    /// - Note: Keep the transform consistent *per game* so leaderboards are fair.
    var rankScore: Int
    
    /// Optional accuracy percentage (0–100) for games where it’s meaningful.
    ///
    /// - Example: shots hit / shots taken * 100.
    var accuracy: Float
    
    /// When this score entry was created.
    ///
    /// Typically set via a Firestore server timestamp on create.
    let createdAt: Date?
    
    /// When this score entry was last updated.
    ///
    /// Typically set via a Firestore server timestamp on update.
    var updatedAt: Date?
    
}
