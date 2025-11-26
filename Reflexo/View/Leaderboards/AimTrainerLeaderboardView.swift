//
//  AimTrainerLeaderboardView.swift
//  Reflexo
//
//  Created by Asmiya Hasan on 13/10/2025.
//

import SwiftUI

/// A SwiftUI screen that shows the **Aim Trainer** global leaderboard.
///
/// ### Overview
/// ``AimTrainerLeaderboardView`` renders a ranked list of the top scores for the
/// *Aim Trainer* mini‑game. It fetches leaderboard entries once on appearance
/// (no live listener) via a ``LeaderboardViewModel`` and then presents a
/// lightweight UI with loading/error/empty/content states.
///
/// The view is intentionally self‑contained and read‑only: it does not mutate
/// remote state. Users can manually refresh using pull‑to‑refresh, which will
/// re‑trigger ``LeaderboardViewModel/load(fb:)``.
///
/// ### Data Sources
/// - Leaderboard data comes from ``FirebaseManager`` through the view model.
/// - Each row is rendered with ``AimTrainerDisplayScore`` using computed rank,
/// the player display name, raw score, accuracy, and the rank‑ordering score.
///
/// ### States
/// - *Loading:* shows a progress indicator.
/// - *Error:* displays a retry affordance.
/// - *Empty:* indicates that there are no scores yet.
/// - *Content:* renders a scrollable list of ranked results.
///

struct AimTrainerLeaderboardView: View {
    @Binding var currentPage: String
    @EnvironmentObject var fb: FirebaseManager
    @StateObject private var vm = LeaderboardViewModel(gameName: "AimTrainer")
    
    var body: some View {
        ZStack {
            Color("Beige").ignoresSafeArea()
            VStack(spacing: 20) {
                Logo()
                HeaderView(title: "Aim Trainer Leaderboard")
                contentView
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.horizontal, 16)
        }
        .task { await vm.load(fb: fb) }   // one-shot fetch; no listeners
    }
    
    @ViewBuilder
    private var contentView: some View {
        if vm.isLoading {
            ProgressView("Loading scores...").padding(.top, 40)
        } else if let msg = vm.errorMessage {
            VStack(spacing: 12) {
                Text(msg).foregroundColor(.red)
                Button("Retry") { Task { await vm.load(fb: fb) } }
                    .buttonStyle(.bordered)
            }
            .padding(.top, 40)
        } else if vm.topScores.isEmpty {
            Text("No scores yet. Be the first to play!")
                .foregroundColor(.black)
                .padding(.top, 40)
        } else {
            leaderboardList(scores: vm.topScores)
        }
    }
    
    /// Builds the scrollable ranked list of leaderboard entries.
    ///
    /// - Parameter scores: The top leaderboard entries already sorted by
    /// ascending ``HighScore/rankScore`` (lower is better).
    /// - Returns: A `ScrollView` containing vertically stacked row views.
    private func leaderboardList(scores: [HighScore]) -> some View {
        // Precompute to keep generics simple for the type-checker
        let ranked = Array(scores.enumerated()).map { (idx, s) in (idx: idx, s: s) }
        return ScrollView {
            VStack(spacing: 16) {
                ForEach(ranked, id: \.idx) { pair in
                    rowView(rank: pair.idx + 1, score: pair.s)
                }
            }
            .padding(.vertical, 10)
        }
        .refreshable { await vm.load(fb: fb) }
    }
    
    /// Renders a single leaderboard row.
    ///
    /// - Parameters:
    /// - rank: One‑based rank in the leaderboard (1 is best).
    /// - score: The ``HighScore`` document containing the user's display name,
    /// raw scores, and computed ``HighScore/rankScore`` used for ordering.
    /// - Returns: A stylized ``AimTrainerDisplayScore`` row.
    private func rowView(rank: Int, score: HighScore) -> some View {
        let colorHex: UInt = (rank == 1) ? 0xcfaa51 : 0x5c6651
        return AimTrainerDisplayScore(
            ranking: String(rank),
            name: "\(score.displayName)",
            score: "Raw score: \(score.score) ms\nAccuracy: \(score.accuracy)%\nComputed score: \(score.rankScore) ms",
            color: colorHex
        )
    }
}
