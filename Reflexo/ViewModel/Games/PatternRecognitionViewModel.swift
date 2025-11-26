//
//  PatternRecognitionViewModel.swift
//  Reflexo
//
//  Created by Rahal De Silva on 11/10/2025.
//

import SwiftUI
import SwiftData
import WidgetKit

/// The state manager for the **Pattern Recognition** mini‑game.
///
/// ### Overview
/// ``PatternRecognitionViewModel`` drives a Simon‑style memory challenge across
/// progressively larger grids. It generates a random set of cells to memorize,
/// shows them for a fixed duration, and then asks the player to recall the
/// pattern by tapping. Results are persisted both locally and (optionally)
/// to Firestore for leaderboards.
///
/// The model is annotated with `@MainActor` so all published state changes occur
/// on the main thread, which is required for SwiftUI.
///
/// ### State Machine
/// The game transitions through these states:
/// - ``State/idle`` – Waiting to start a level or between rounds.
/// - ``State/showPattern`` – The target pattern is visible for ``showDuration``.
/// - ``State/recall`` – The player is tapping cells to reproduce the pattern.
/// - ``State/success`` – The round was completed correctly.
/// - ``State/gameOver`` – A mistake was made; the round ends.
///
/// ### Scoring
/// - **Score** = current ``gridSize`` (the side length) at the moment the round
/// ends (success or failure). This is also used as the `rankScore`.
/// - **Accuracy** = `1` on success, `0` on failure.
///
/// ### Persistence
/// Uses ``FirebaseManager/saveHighScore(game:score:rankScore:accuracy:)`` to
/// write cloud scores for global leaderboards, and ``GameRecord/saveLocal(_context:uid:displayName:game:score:rankScore:accuracy:)``
/// to store local history. Attach a `ModelContext` via ``attach(modelContext:)``
/// when you want local persistence.
///
@MainActor
final class PatternRecognitionViewModel: ObservableObject {
    
    private let session = UserSessionManager.shared
    private var modelContext: ModelContext?
    
    // MARK: - State
    /// Discrete phases of the game loop.
    enum State { case idle, showPattern, recall, success, gameOver }
    
    /// Current grid side length (e.g., 4 → 4×4 grid).
    @Published var gridSize: Int = 4
    
    /// Maximum grid side length before cycling back.
    let maxGridSize: Int = 10
    var showDuration: Double = 2.0
    
    /// Current finite‑state‑machine state.
    @Published var state: State = .idle
    /// The set of cell indices that form the target pattern for this round.
    @Published var pattern: Set<Int> = []
    /// The set of cells the player has tapped during recall.
    @Published var selection: Set<Int> = []
    /// A UI‑friendly instruction/status line.
    @Published var message: String = "Remember and Recall the grid pattern."
    /// Player progression within the session (increments with each grid).
    @Published var level: Int = 1
    
    /// Any scheduled task that will hide the pattern and switch to recall.
    private var pendingHideTask: Task<Void, Never>?
    private let fb = FirebaseManager.shared
    
    // MARK: - Setup
    /// Provide a `ModelContext` for local persistence (opt
    func attach(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // MARK: - Game flow
    /// Starts a new level by generating a pattern and scheduling the hide.
    ///
    /// - Parameter totalCells: The total number of cells in the grid (e.g.,
    /// `gridSize * gridSize`).
    func startLevel(totalCells: Int) {
        resetRound()
        pattern = makePattern(totalCells: totalCells)
        state = .showPattern
        message = "Memorise the cells…"
        
        pendingHideTask?.cancel()
        pendingHideTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: UInt64(showDuration * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self.state = .recall
                self.message = "Now tap the cells."
            }
        }
    }
    
    /// Handles a tap during the recall phase, updating selection and detecting mistakes.
    /// - Parameter index: The tapped cell's linear index.
    func tapCell(_ index: Int) {
        guard state == .recall else { return }
        
        if !pattern.contains(index) {
            finish(success: false)
            return
        }
        
        selection.insert(index)
        
        if selection == pattern {
            state = .success
            message = "Correct! Get ready for the next grid."
        }
    }
    
    /// Resets progression to the starting grid and level, ready to play again.
    func retrySameGrid() {
        gridSize = 4
        level = 1
        selection.removeAll()
        state = .idle
        message = "Memorise the pattern, then tap those cells."
    }
    
    /// Advances to the next grid size (up to ``maxGridSize``) or cycles back to 4×4.
    func nextGrid() {
        guard gridSize < maxGridSize else {
            gridSize = 4
            level = 1
            state = .idle
            message = "Completed! Restarting at 4×4."
            return
        }
        gridSize += 1
        level += 1
        state = .idle
        message = "Memorise the pattern, then tap those cells."
    }
    
    /// Clears round‑specific state.
    private func resetRound() {
        selection.removeAll()
        pattern.removeAll()
        state = .idle
    }
    
    // MARK: - Pattern generation
    /// Creates a random set of cell indices (~30% of the grid) for the pattern.
    ///
    /// - Parameter totalCells: The number of cells in the current grid.
    /// - Returns: A set of unique indices representing the pattern.
    private func makePattern(totalCells: Int) -> Set<Int> {
        let count = max(3, Int(round(Double(totalCells) * 0.30)))
        var all = Array(0..<totalCells)
        all.shuffle()
        return Set(all.prefix(count))
    }
    
    // MARK: - Finish & persistence
    /// Finalizes the round, sets end state, and persists the result.
    ///
    /// - Parameter success: Whether the player's last action completed the pattern.
    private func finish(success: Bool) {
        state = success ? .success : .gameOver
        message = success ? "Correct! Get ready for the next grid." : "Incorrect. Try again."
        
        let accuracyVal = success ? 1 : 0
        let scoreVal = gridSize
        let _game = "PatternRecognition"
        
        Task {
            do {
                try await fb.saveHighScore(
                    game: _game,
                    score: scoreVal,
                    rankScore: scoreVal,
                    accuracy: accuracyVal
                )
                
                print("Saved on Firebase")
            } catch {
                print("Failed to save to Firebase")
            }

            GameRecord.saveLocal(
                _context: modelContext,
                uid: session.uid,
                displayName: session.displayName,
                game: _game,
                score: scoreVal,
                rankScore: scoreVal,
                accuracy: Float(accuracyVal))
        }
    }
    
    func saveProgressOnExit() {
        guard state == .recall || state == .success || state == .gameOver else { return }

        let success = state == .success
        let accuracyVal = success ? 1 : 0
        let scoreVal = gridSize
        let _game = "PatternRecognition"

        Task {
            do {
                try await fb.saveHighScore(
                    game: _game,
                    score: scoreVal,
                    rankScore: scoreVal,
                    accuracy: accuracyVal
                )
                print("Saved onto Firebase")
            } catch {
                print("Failed to save onto Firebase")
            }

            GameRecord.saveLocal(
                _context: modelContext,
                uid: session.uid,
                displayName: session.displayName,
                game: _game,
                score: scoreVal,
                rankScore: scoreVal,
                accuracy: Float(accuracyVal))
        }
    }


}
