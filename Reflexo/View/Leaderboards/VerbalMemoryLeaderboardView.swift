//
//  VerbalMemoryLeaderboardView.swift
//  Reflexo
//
//  Created by Asmiya Hasan on 13/10/2025.
//

import SwiftUI

/// A SwiftUI screen that shows the **Verbal Memory** global leaderboard.
///
/// ### Overview
/// ``VerbalMemoryLeaderboardView`` fetches and displays the top scores for the
/// *Verbal Memory* mini‑game. It uses ``LeaderboardViewModel`` to query Firestore
/// via ``FirebaseManager`` and renders a friendly UI with loading, error, empty,
/// and content states.
///
/// This view performs a one‑shot fetch on appearance (no live listener). Users
/// can pull to refresh to retrieve the latest results.
///
/// ### Data Flow
/// 1. ``LeaderboardViewModel`` is initialized with `gameName: "VerbalMemory"`.
/// 2. ``LeaderboardViewModel/load(fb:)`` reads the leaderboard once.
/// 3. ``LeaderboardViewModel/topScores`` drives the list; each entry is rendered
/// with ``DisplayScore`` showing the player's name and raw score.
///
/// ### States
/// - **Loading** → `ProgressView("Loading scores…")`
/// - **Error** → Inline message in red with a **Retry** button
/// - **Empty** → A friendly prompt when no scores exist yet
/// - **Content** → Scrollable ranked list of entries
struct VerbalMemoryLeaderboardView: View {
    @Binding var currentPage: String
    @EnvironmentObject var fb: FirebaseManager
    @StateObject private var vm = LeaderboardViewModel(gameName: "VerbalMemory")
    
    var body: some View {
        ZStack {
            Color("Beige").ignoresSafeArea()
            VStack(spacing: 20) {
                Logo()
                HeaderView(title: "Verbal Memory Leaderboard")
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
    
    private func rowView(rank: Int, score: HighScore) -> some View {
        let colorHex: UInt = (rank == 1) ? 0xcfaa51 : 0x5c6651
        return DisplayScore(
            ranking: String(rank),
            name: "\(score.displayName)",
            score: "\(score.score)",
            color: colorHex
        )
    }
}
