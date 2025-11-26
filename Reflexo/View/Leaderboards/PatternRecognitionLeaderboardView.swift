//
//  PatternRecognitionLeaderboardView.swift
//  Reflexo
//
//  Created by Asmiya Hasan on 13/10/2025.
//

import SwiftUI

/// A SwiftUI screen that shows the **Pattern Recognition** global leaderboard.
///
/// ### Overview
/// ``PatternRecognitionLeaderboardView`` fetches and displays the top scores for the
/// *Pattern Recognition* mini‑game. It uses ``LeaderboardViewModel`` to load results
/// from Firestore via ``FirebaseManager`` and renders a simple, accessible UI with
/// loading, error, empty, and content states.
///
/// The view performs a one‑shot fetch on appear (no live listener). Users can pull to
/// refresh to re‑query the latest results without leaving the screen.
///
/// ### Data Flow
/// 1. ``LeaderboardViewModel`` is initialized with `gameName: "PatternRecognition"`.
/// 2. ``LeaderboardViewModel/load(fb:)`` reads the leaderboard once.
/// 3. ``topScores`` drives the list; each row is built by ``DisplayScore``.
///
/// ### States
/// - **Loading** → `ProgressView("Loading scores…")`
/// - **Error** → Message in red + **Retry** button
/// - **Empty** → A friendly prompt when no scores exist
/// - **Content** → Scrollable ranked list of entries
///
struct PatternRecognitionLeaderboardView: View {
    @Binding var currentPage: String
    @EnvironmentObject var fb: FirebaseManager
    @StateObject private var vm = LeaderboardViewModel(gameName: "PatternRecognition")
    
    var body: some View {
        ZStack {
            Color("Beige").ignoresSafeArea()
            VStack(spacing: 20) {
                Logo()
                HeaderView(title: "Pattern Recognition Leaderboard")
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
                .foregroundColor(.white)
                .padding(.top, 40)
        } else {
            leaderboardList(scores: vm.topScores)
        }
    }
    
    /// Builds the scrollable ranked list of leaderboard entries.
    ///
    /// - Parameter scores: Leaderboard entries sorted by ascending
    /// ``HighScore/rankScore`` (lower is better) by the view model.
    /// - Returns: A `ScrollView` with a vertical stack of rows.
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
    
    /// Renders a single leaderboard row using ``DisplayScore``.
    ///
    /// - Parameters:
    /// - rank: One‑based leaderboard position.
    /// - score: The ``HighScore`` record with the user's display name and values.
    /// - Returns: A stylized row view.
    private func rowView(rank: Int, score: HighScore) -> some View {
        let colorHex: UInt = (rank == 1) ? 0xcfaa51 : 0x5c6651
        return DisplayScore(
            ranking: String(rank),
            name: "\(score.displayName)",
            score: "Level \(score.score)",
            color: colorHex
        )
    }
}
