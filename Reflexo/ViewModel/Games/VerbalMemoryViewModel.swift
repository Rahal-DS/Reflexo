//
//  VerbalMemoryViewModel.swift
//  Reflexo
//
//  Created by Asmiya Hasan on 12/10/2025.
//

import SwiftUI
import SwiftData
import WidgetKit


/// The state manager for the **Verbal Memory** mini‑game.
///
/// ### Overview
/// ``VerbalMemoryViewModel`` powers a *Seen vs. Unseen* word‑recall game. It
/// loads a cache of unique words (from a ``RandomWordService`` or a local
/// fallback), streams them to the UI, tracks score and lives, and persists new
/// personal bests to Firestore while saving local attempts to SwiftData for
/// history and widgets. The model is annotated `@MainActor` so published state
/// updates are safe for SwiftUI.
///
/// ### Game States
/// - ``GameState/idle`` – Waiting to begin.
/// - ``GameState/loading`` – Fetching or preparing the word cache.
/// - ``GameState/playing`` – Serving words; accepts **Seen/Unseen** choices.
/// - ``GameState/gameOver`` – Out of lives; optionally persists best.
/// - ``GameState/error(_:)`` – Reserved for unrecoverable errors (currently not thrown).
///
/// ### Mechanics
/// - The session builds a shuffled cache of unique words (`allWords`).
/// - With probability ``pUnseen`` (default **0.6**), the next word is unseen if
/// available; otherwise a random item from ``seen`` is repeated.
/// - Correct guesses increment ``score``; wrong guesses decrement ``lives`` from 3.
/// - On game over, a new personal best is written if it beats the prior best.
///
/// ### Persistence
/// - **Cloud (leaderboard):** ``FirebaseScoresManager/saveHighScore(game:score:rankScore:accuracy:)``.
/// `rankScore` is `-score` so higher scores rank first.
/// - **Local (history/widgets):** ``GameRecord/saveLocal(_context:uid:displayName:game:score:rankScore:accuracy:)``.
/// - Widgets are nudged via `WidgetCenter.shared.reloadAllTimelines()` (from the save path).
@MainActor
final class VerbalMemoryViewModel: ObservableObject {
    
    // MARK: - Game state
    /// Discrete phases of the Verbal Memory session.
    enum GameState: Equatable {
        case idle
        case loading
        case playing
        case gameOver
        case error(String)
    }
    
    // MARK: - Dependencies
    private let session = UserSessionManager.shared
    private let service: RandomWordService
    private let fbScores = FirebaseScoresManager.shared
    private var modelContext: ModelContext?
    private let cacheSize: Int
    
    // MARK: - Published UI model
    /// Current high‑level state of the game.
    @Published private(set) var state: GameState = .idle
    /// Current score (increments on correct guesses).
    @Published private(set) var score: Int = 0
    /// Remaining lives (starts at 3 and decrements on mistakes).
    @Published private(set) var lives: Int = 3
    /// The word currently shown to the player.
    @Published private(set) var currentWord: String = ""
    /// Count of unique words the player has seen this session.
    @Published private(set) var seenCount: Int = 0
    /// Best score for the signed‑in user (UI convenience; not authoritative).
    @Published var bestScore: Int = 0
    
    // MARK: - Internals
    private var allWords: [String] = []   // unique cache for this run
    private var idx: Int = 0              // pointer into unseen list
    private var seen: Set<String> = []    // words the player has actually encountered
    private var rng = SystemRandomNumberGenerator()
    
    /// Probability of serving an unseen word when available.
    private let pUnseen: Double = 0.6
    
    // MARK: - Init & setup
    /// Creates a view model with a word source and desired cache size.
    /// - Parameters:
    /// - service: The word provider used to fetch unique words.
    /// - cacheSize: Number of unique words to prepare per run (default 50).
    init(service: RandomWordService, cacheSize: Int = 50) {
        self.service = service
        self.cacheSize = cacheSize
    }
    
    func attach(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    

    // MARK: - Public API
    /// Starts a new session by fetching (or synthesizing) words, then switches to ``GameState/playing``.
    func startGame() {
        Task {
            await loadWordsAndBegin()
        }
    }
    /// Restarts with a fresh cache (re‑fetches words).
    func restart() {
        // Fresh cache each time → fetch again
        startGame()
    }
    /// Records a *Seen* choice.
    func chooseSeen() {
        handleChoice(guessIsSeen: true)
    }
    /// Records an *Unseen* choice.
    func chooseUnseen() {
        handleChoice(guessIsSeen: false)
    }
    
    // MARK: - Core flow
    /// Loads a cache of words (network with offline fallback) and begins play.
    private func loadWordsAndBegin() async {
        state = .loading
        score = 0
        lives = 3
        idx = 0
        seen = []
        seenCount = 0
        currentWord = ""
        
        do {
            let fetched = try await service.fetchWords(count: cacheSize)
            // Guarantee we have enough to play; fallback if the API misbehaves.
            self.allWords = fetched.isEmpty ? Self.fallbackWords(count: cacheSize) : fetched
            self.allWords.shuffle()
            
            state = .playing
            nextWord()
        } catch {
            // Fallback to local list if network fails, so game can still run offline
            self.allWords = Self.fallbackWords(count: cacheSize).shuffled()
            state = .playing
            nextWord()
        }
    }
    /// Evaluates a user's choice, updates score/lives, and advances the stream.
    /// - Parameter guessIsSeen: `true` if the player chose *Seen*, else *Unseen*.
    private func handleChoice(guessIsSeen: Bool) {
        guard state == .playing, !currentWord.isEmpty else { return }
        
        let actuallySeen = seen.contains(currentWord)
        if guessIsSeen == actuallySeen {
            score += 1
        } else {
            lives -= 1
            if lives <= 0 {
                state = .gameOver
                Task { await saveScoreIfBest() }
                GameRecord.saveLocal(
                    _context: modelContext,
                    uid: session.uid,
                    displayName: session.displayName,
                    game: "VerbalMemory",
                    score: score,
                    rankScore: -score,
                    accuracy: 1.0
                )
                return
            }
        }
        
        // After answering, the current word becomes seen (if it wasn’t already)
        if !actuallySeen {
            seen.insert(currentWord)
            seenCount = seen.count
        }
        
        nextWord()
    }
    /// Chooses and shows the next word based on ``pUnseen`` and available sets.
    private func nextWord() {
        guard state == .playing else { return }
        
        let shouldServeUnseen = (idx < allWords.count) && Bool.random(probability: pUnseen, using: &rng)
        
        if shouldServeUnseen {
            currentWord = allWords[idx]
            idx += 1
            return
        }
        
        // Otherwise, serve a repeat (only if we have any seen words)
        if let repeatWord = seen.randomElement(using: &rng) {
            currentWord = repeatWord
            return
        }
        
        // If nothing seen yet, we must serve unseen
        if idx < allWords.count {
            currentWord = allWords[idx]
            idx += 1
        } else {
            // Edge case: ran out of unseen and nothing seen (practically impossible)
            // Loop words so game continues; or you could end the game here.
            reshuffleSeenIntoUnseen()
            nextWord()
        }
    }
    
    /// Recycles the seen set back into the unseen pool if needed.
    private func reshuffleSeenIntoUnseen() {
        // Safety net: if we exhaust unseen (idx >= allWords.count), recycle seen set
        guard !seen.isEmpty else { return }
        allWords = Array(seen)
        allWords.shuffle()
        idx = 0
    }
    /// Saves a new personal best to Firestore (if higher than previous) and refreshes widgets.
    func saveScoreIfBest() async {
        guard case .gameOver = state else { return }
        
        do {
            let currentBest = try await fbScores.getMyBestScore(game: "VerbalMemory")
            if let best = currentBest?.score, best >= score { return }
            
            try await fbScores.saveHighScore(game: "VerbalMemory", score: score, rankScore: -score, accuracy: 1)
            
            WidgetCenter.shared.reloadAllTimelines()
            
        } catch {
            print("Failed to save best verbal_memory score: \(error)")
        }
    }
    
    // MARK: - Utilities
    /// Local fallback wordbank used when the network/API is unavailable.
    /// - Parameter count: Desired number of unique words.
    /// - Returns: A list of at most `count` words.
    private static func fallbackWords(count: Int) -> [String] {
        let base = [
            "apple","river","cloud","stone","lamp","novel","tiger","piano","garden","planet",
            "cookie","bridge","coffee","mirror","rocket","pear","shadow","candle","stream","violet",
            "castle","forest","compass","puzzle","ocean","mountain","island","silver","gold","bronze",
            "window","pillow","blanket","helmet","guitar","violin","drum","camera","clock","wallet",
            "ticket","hammer","ladder","basket","painter","singer","dancer","writer","pilot","doctor",
            "pepper","butter","bottle","drawer","notebook","skylight","harbor","desert","glacier","meadow"
        ]
        let pool = Array(repeating: base, count: max(1, (count + base.count - 1) / base.count)).flatMap { $0 }
        return Array(pool.prefix(count))
    }
    
}

// MARK: - Helpers

extension Bool {
    // MARK: - Helpers
    static func random<T: RandomNumberGenerator>(probability p: Double, using rng: inout T) -> Bool {
        precondition(p >= 0 && p <= 1, "Probability must be in [0,1]")
        return Double.random(in: 0...1, using: &rng) < p
    }
}
