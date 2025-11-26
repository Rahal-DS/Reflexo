//
//  GamesView.swift
//  Reflexo
//
//  Created by Asmiya Hasan on 31/8/2025.
//

import SwiftUI
/// The **Play** hub listing all available mini-games in Reflexo.
///
/// `GamesView` presents branded game tiles that navigate to each game screen.
/// The parent view provides a binding to the routing state (`currentPage`),
/// which is updated when a tile is tapped.
struct GamesView: View
{
    @Binding var currentPage: String
    var body: some View
    {
        VStack(spacing: 20) {
            Logo()
            HeaderView(title: "Play")
            
            ScrollView {
                EqualHeightVStack (spacing: 20, horizontalPadding: 90) {
                    GameButton(label: "Reaction Time", desc: "Test your visual reflexes", color: 0x788c62, icon: "thunder", currentPage: $currentPage,  nextPage: Route.reactionTime)
                    GameButton(label: "Pattern Recognition", desc: "Recall grid patterns", color: 0x5c6651, icon: "blocks", currentPage: $currentPage,  nextPage: Route.patternRecognition)
                    GameButton(label: "Aim Trainer", desc: "How quickly can you hit all of the targets?", color: 0x93998d, icon: "bullseye", currentPage: $currentPage,  nextPage: Route.aimTrainer)
                    GameButton(label: "Verbal Memory", desc: "Keep as many words in short term memory as possible", color: 0x4d4b47, icon: "dictionary", currentPage: $currentPage,  nextPage: Route.verbalMemory)
                }
            }
        }
        
    }
    
}
/// Identifiers for mini-games displayed in ``GamesView``.
enum Game: String {
    case reactionTime = "ReactionTime"
    case verbalMemory = "VerbalMemory"
    case aimTrainer = "AimTrainer"
    case patternRecognition = "PatternRecognition"
}



