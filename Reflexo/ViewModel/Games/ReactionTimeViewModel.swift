//
//  ReactionTimeViewModel.swift
//  Reflexo
//
//  Created by Asmiya Hasan on 10/10/2025.
//
import SwiftUI
import SwiftData
import WidgetKit

/// The state manager for the **Reaction Time** mini‑game.
///
/// ### Overview
/// ``ReactionTimeViewModel`` orchestrates the single‑tap reaction test flow:
/// it schedules a randomized delay, arms taps, flips the UI to *green* ("ready"),
/// measures the user's reaction time in milliseconds, and persists results both
/// to the cloud (leaderboards) and locally (history/widgets). The model is
/// `@MainActor` so SwiftUI updates are performed safely on the main thread.
///
/// ### Game States
/// - ``GameState/idle`` – Waiting to start.
/// - ``GameState/waiting`` – Red screen; delay running but taps not yet armed.
/// - ``GameState/ready`` – Green screen; next tap records the reaction.
/// - ``GameState/tooSoon`` – The user tapped during *waiting* (false start).
/// - ``GameState/result(ms:)`` – Shows the most recent reaction time.
///
/// ### Timing & Scoring
/// - A randomized delay in **[1200, 3500] ms** is used before going green.
/// - The reaction time is computed from `DispatchTime` nanoseconds.
/// - ``bestMs`` holds the session's personal best; cloud best is fetched on appear.
/// - Leaderboard ordering uses the raw millisecond value as both `score` and
/// `rankScore` (lower is better) with accuracy fixed to `1` on valid results.
///
/// ### Persistence
/// - **Cloud:** ``FirebaseScoresManager/saveHighScore(game:score:rankScore:accuracy:)``
/// - **Local:** ``GameRecord/saveLocal(_context:uid:displayName:game:score:rankScore:accuracy:)``
/// - Widgets are nudged via `WidgetCenter.shared.reloadAllTimelines()` after save.
///
/// ### Cancellation & Safety
/// - Any pending delay task is cancelled by ``cancelDelay()`` when restarting or
/// on false starts to avoid double state transitions.
/// - Taps are ignored until ``tapArmed`` is set (briefly after entering *waiting*)
/// so the Start tap doesn't count as a false start.
@MainActor
final class ReactionTimeViewModel: ObservableObject {
    private let session = UserSessionManager.shared
    private let fbScores = FirebaseScoresManager.shared
    
    /// Discrete phases of the reaction‑time test.
    enum GameState: Equatable { case idle, waiting, ready, tooSoon, result(ms: Int) }

    /// Current game state.
    @Published var state: GameState = .idle
    /// Whether taps should be honored (becomes true shortly after entering *waiting*).
    @Published var tapArmed = false
    /// Session personal‑best (ms). Defaults to `Int.max` until a valid result is recorded or fetched.
    @Published var bestMs: Int = .max

    
    /// Timestamp when the UI switched to *ready* (green).
    private var greenShownAt: DispatchTime?
    /// The scheduled async delay task before switching to green.
    private var pendingTask: Task<Void, Never>?

    /// Minimum/maximum randomized delay before going green (milliseconds).
    private let minDelayMs = 1200
    private let maxDelayMs = 3500
    
    private var modelContext: ModelContext?
    
    // MARK: - Setup
    /// Provide a `ModelContext` for local saves (optional).
    func attach(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    /// Fetches the cloud personal best when the screen appears.
    func onAppear() {
        Task { await refreshBestFromCloud() }
    }
    
    // MARK: - Game flow
    /// Starts a round: schedules the randomized delay and arms taps after a short guard.
    func startRound() {
        cancelDelay()
        state = .waiting
        tapArmed = false
        
        let delayMs = Int.random(in: minDelayMs...maxDelayMs)
        
        pendingTask = Task { [weak self] in
            guard let self else { return }
            
            // arm taps a hair AFTER we enter waiting, so the Start tap won't count
            try? await Task.sleep(nanoseconds: 120_000_000) // 120ms
            guard !Task.isCancelled else { return }
            self.tapArmed = true
            
            // now wait the randomized delay before going green
            try? await Task.sleep(nanoseconds: UInt64(delayMs) * 1_000_000)
            guard !Task.isCancelled else { return }
            
            self.greenShownAt = .now()
            withAnimation(.easeIn(duration: 0.08)) {
                self.state = .ready
            }
        }
    }
    
    /// Handles a user tap depending on the current state.
    func handleTap() {
        guard tapArmed else { return } // ignore stray taps before arming
        
        switch state {
        case .waiting:
            // false start
            cancelDelay()
            withAnimation { state = .tooSoon }
            
        case .ready:
            guard let t0 = greenShownAt else { return }
            let elapsedNs = DispatchTime.now().uptimeNanoseconds - t0.uptimeNanoseconds
            let ms = max(0, Int(Double(elapsedNs) / 1_000_000.0))
            if ms < bestMs { bestMs = ms }
            withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                state = .result(ms: ms)
            }
            
            Task {
                do {
                    try await fbScores.saveHighScore(game: "ReactionTime", score: bestMs, rankScore: bestMs, accuracy: 1)
                    
                    WidgetCenter.shared.reloadAllTimelines()
                    
                }
                catch { print("Save failed: \(error)") }
                await refreshBestFromCloud()
            }
            
            GameRecord.saveLocal(
                _context: modelContext,
                uid: session.uid,
                displayName: session.displayName,
                game: "ReactionTime",
                score: bestMs,
                rankScore: bestMs,
                accuracy: 1.0
            )
            
            
        case .idle, .tooSoon, .result:
            break
        }
    }
    
    /// Clears the in‑memory personal best for the session.
    func resetBest() { bestMs = .max }
    
    /// Cancels any pending delay and resets timing flags.
    func cancelDelay() {
        pendingTask?.cancel()
        pendingTask = nil
        greenShownAt = nil
        tapArmed = false
    }
    
    // MARK: - Cloud sync
    /// Refreshes the user's cloud personal best and updates ``bestMs``.
    private func refreshBestFromCloud() async {
        do {
            if let hs = try await fbScores.getMyBestScore(game: "ReactionTime") {
                bestMs = hs.score   // uses your HighScore.score (ms)
            } else {
                bestMs = .max
            }
        } catch {
            // Keep previous UI value on error
            print("Fetch best failed: \(error)")
        }
    }
    
    // MARK: - Local data utilities
    /// Loads all local ``GameRecord`` attempts (most recent first).
    func loadAllAttempts(from ctx: ModelContext) throws -> [GameRecord] {
        let fd = FetchDescriptor<GameRecord>(
            sortBy: [SortDescriptor(\.attemptedAt, order: .reverse)]
        )
        return try ctx.fetch(fd)
    }
    

    
    /// Debug helper to print all attempts to the console.
    func dumpAllAttemptsToConsole(ctx: ModelContext) {
        do {
            let fd = FetchDescriptor<GameRecord>(
                sortBy: [SortDescriptor(\.attemptedAt, order: .reverse)]
            )
            let rows = try ctx.fetch(fd)
            print("— All GameAttempt rows (\(rows.count)) —")
            for a in rows {
                print("[\(a.attemptedAt)] \(a.game) uid=\(a.uid) name=\(a.displayName) score=\(a.score) accuracy=\(a.accuracy) rank=\(a.rankScore)")
            }
        } catch {
            print("Dump failed:", error)
        }
    }
    
}
