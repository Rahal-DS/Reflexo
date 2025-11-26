//
//  GameRecord.swift
//  Reflexo
//
//  Created by Asmiya Hasan on 12/10/2025.
//

import Foundation
import SwiftData
import WidgetKit

/// A local, SwiftData-backed record of a single game attempt.
///
/// `GameRecord` mirrors the fields you store in a SwiftData database
/// so you can persist attempts offline, power widgets, and show local history even when
/// the network is unavailable.
///
/// - Note: `rankScore` is the value used for ordering leaderboards (lower is better).
/// - Important: The model uses a unique `UUID` as `id`. Each saved attempt is a new row.

@Model
final class GameRecord {
    
    /// Unique identifier for this local attempt.
    @Attribute(.unique) var id: UUID
    
    /// Firebase Authentication user ID (or `"local"` when not signed in).
    var uid: String
    
    /// Denormalized display name for quick UI rendering.
    var displayName: String
    
    /// Game identifier (e.g., `"ReactionTime"`, `"VerbalMemory"`).
    var game: String
    
    /// Raw score displayed to the user (e.g., milliseconds for reaction time).
    var score: Int
    
    /// Score used for ranking (lower is better for speed-based games).
    var rankScore: Int
    
    /// Optional accuracy metric for the attempt (0.0—1.0).
    var accuracy: Float
    
    /// Timestamp when the attempt occurred.
    var attemptedAt: Date

    /// Creates a new game attempt record.
    ///
    /// - Parameters:
    ///   - uid: Firebase user ID (or `"local"` if offline/anonymous).
    ///   - displayName: User’s display name denormalized for quick reads.
    ///   - game: The game identifier.
    ///   - score: Raw score to display.
    ///   - rankScore: Score used to sort leaderboards (lower is better).
    ///   - accuracy: Accuracy percentage for the attempt.
    ///   - attemptedAt: When the attempt happened (defaults to `now`).
    init(
        uid: String,
        displayName: String,
        game: String,
        score: Int,
        rankScore: Int,
        accuracy: Float,
        attemptedAt: Date = .now
    ) {
        self.id = UUID()
        self.uid = uid
        self.displayName = displayName
        self.game = game
        self.score = score
        self.rankScore = rankScore
        self.accuracy = accuracy
        self.attemptedAt = attemptedAt
    }
}

extension GameRecord
{
    @MainActor
    static func saveLocal(
        _context: ModelContext?,
        uid: String?,
        displayName: String,
        game: String,
        score: Int,
        rankScore: Int,
        accuracy: Float
    )
    {
        guard let context = _context else {
            print("Can't save locally, missing ModelState")
            return
        }
        
        let record = GameRecord(
            uid: uid ?? "local",
            displayName: displayName,
            game: game,
            score: score,
            rankScore: rankScore,
            accuracy: accuracy,
            attemptedAt: .now
        )
        
        context.insert(record)
        
        do
        {
            try context.save()

            if let defaults = UserDefaults(suiteName: "group.com.ReflexoShared") {
                defaults.set(score, forKey: "\(game)_lastScore")
                defaults.set(displayName, forKey: "lastPlayerName")
                defaults.synchronize()
            }

            WidgetCenter.shared.reloadAllTimelines()
            print("Saved to local storage")
        } catch
        {
            print("Failed to save to local storage")
        }
    }
    
    @MainActor
        static func fetchBestScores(from context: ModelContext?) -> [String: Int] {
            guard let context = context else {
                print("Missing ModelContext for fetching scores")
                return [:]
            }

            let games = ["ReactionTime", "AimTrainer", "PatternRecognition", "VerbalMemory"]
            var results: [String: Int] = [:]

            do {
                let descriptor = FetchDescriptor<GameRecord>(
                    sortBy: [SortDescriptor(\.attemptedAt, order: .reverse)]
                )
                let records = try context.fetch(descriptor)

                for game in games {
                    let filtered = records.filter { $0.game == game }

                    if ["ReactionTime", "AimTrainer"].contains(game) {
                        let sorted = filtered.sorted { $0.rankScore < $1.rankScore }
                        results[game] = sorted.first?.score ?? 0
                    } else {
                        let sorted = filtered.sorted { $0.rankScore > $1.rankScore }
                        results[game] = sorted.first?.score ?? 0
                    }
                }

                print("Best scores fetched: \(results)")
            } catch {
                print("Failed to fetch best scores:", error.localizedDescription)
            }

            return results
        }
}


