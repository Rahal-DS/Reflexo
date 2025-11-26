//
//  ScoreboardView.swift
//  Reflexo
//
//  Created by Asmiya Hasan on 31/8/2025.
//

import SwiftUI
/// A hub screen for navigating to each game's global leaderboard.
///
/// ### Overview
/// ``ScoreboardView`` presents a simple menu of game entries. Each entry is a
/// ``GameButton`` that routes to the corresponding leaderboard page using a
/// shared `currentPage` binding and your app's ``Route`` enum.
///
/// This view does not fetch network data itself; it only provides navigation to
/// leaderboards such as ``ReactionTimeLeaderboardView``, ``PatternRecognitionLeaderboardView``,
/// ``AimTrainerLeaderboardView``, and ``VerbalMemoryLeaderboardView``.
///
/// ### Navigation
/// Tapping a button updates the ``currentPage`` binding to the appropriate
/// ``Route`` (for example, ``Route/reactionTimeLeaderboard``). The actual
/// navigation logic is handled by the parent container that observes
/// `currentPage`.
struct ScoreboardView: View
{
    @Binding var currentPage: String
    var body: some View
    {
        VStack(spacing: 20) {
            Logo()
            HeaderView(title: "Leaderboards")
            Text("Choose game to view global leaderboard")
            
            ScrollView {
                
                EqualHeightVStack (spacing: 20, horizontalPadding: 90)  {
                    GameButton(label: "Reaction Time", desc: "", color: 0x788c62, icon: "thunder", currentPage: $currentPage,  nextPage: Route.reactionTimeLeaderboard)
                    GameButton(label: "Pattern Recognition", desc: "", color: 0x5c6651, icon: "blocks", currentPage: $currentPage,  nextPage: Route.patternRecognitionLeaderboard)
                    GameButton(label: "Aim Trainer", desc: "", color: 0x93998d, icon: "bullseye", currentPage: $currentPage,  nextPage: Route.aimTrainerLeaderboard)
                    GameButton(label: "Verbal Memory", desc: "", color: 0x4d4b47, icon: "dictionary", currentPage: $currentPage,  nextPage: Route.verbalMemoryLeaderboard)
                    
                }
            }
        }
        
    }
    
}
