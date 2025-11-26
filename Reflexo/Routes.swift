//
//  Routes.swift
//  Reflexo
//
//  Created by Asmiya Hasan on 10/10/2025.
//

// Routes.swift

/// A centralized list of string route identifiers used for navigation
/// across the Reflexo app.
///
/// Use these constants to avoid hard-coding route names in your views,
/// view models, and navigation logic. Keeping all route strings in one
/// place reduces typos and makes refactors safer.
///
/// ### Usage
/// ```swift
/// // Example: setting the current page
/// @State private var currentPage = Route.home
///
/// // Navigate to Reaction Time
/// currentPage = Route.reactionTime
/// ```
///
/// ### Topics
/// - Navigation Containers:
///   - ``home``
///   - ``authGate``
///   - ``games``
///   - ``leaderboards``
///   - ``profile``
///   - ``settings```
/// - Leaderboard Screens:
///   - ``reactionTimeLeaderboard``
///   - ``verbalMemoryLeaderboard``
///   - ``aimTrainerLeaderboard``
///   - ``patternRecognitionLeaderboard```
/// - Game Screens:
///   - ``reactionTime``
///   - ``aimTrainer``
///   - ``verbalMemory``
///   - ``patternRecognition``
enum Route {
    static let home                     = "Home"
    static let login                    = "Login"
    static let signup                   = "Signup"
    static let authGate                 = "AuthGate"
    static let games                    = "Games"
    static let profile                  = "Profile"
    static let settings                 = "Settings"
    static let leaderboards             = "Leaderboards"
    static let reactionTimeLeaderboard   = "ReactionTimeLeaderboard"
    static let verbalMemoryLeaderboard   = "VerbalMemoryLeaderboard"
    static let aimTrainerLeaderboard   = "AimTrainerLeaderboard"
    static let patternRecognitionLeaderboard   = "PatternRecognitionLeaderboard"

    // Games
    static let reactionTime             = "ReactionTime"
    static let aimTrainer               = "AimTrainer"
    static let verbalMemory             = "VerbalMemory"
    static let patternRecognition       = "PatternRecognition"

    // MARK: - Helpers

    /// Returns `true` if the provided page identifier corresponds to a game screen.
    ///
    /// - Parameter page: A route identifier string, typically one of the static constants in ``Route``.
    /// - Returns: `true` if `page` is one of ``reactionTime``, ``aimTrainer``, ``patternRecognition``,
    ///   or ``verbalMemory``; otherwise `false`.
    static func isGame(_ page: String) -> Bool {
        [reactionTime, aimTrainer, patternRecognition, verbalMemory].contains(page)
    }
}
