//
//  Buttons.swift
//  Reflexo
//
//  Created by Asmiya Hasan on 10/10/2025.
//

import SwiftUI

/// A tactile button style that provides press feedback via opacity and scale.
///
/// The style lowers opacity and slightly shrinks the label while the button
/// is pressed, then animates back on release.
///
/// ### Usage
/// ```swift
/// Button("Tap me") { /* action */ }
///   .buttonStyle(PressableButtonStyle())
/// ```
///
struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.6 : 1.0) // lower opacity when pressed
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0) // optional "shrink" effect
            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
    }
}

/// A fixed-size square navigation button with an SF Symbol and label.
///
/// Tapping the button updates a bound routing state to navigate within
/// the app. The button renders a 150×150pt rounded square with a
/// colored background, icon, and title.
///
/// ### Example
/// ```swift
/// SquareButton(
///   label: "Reaction",
///   color: 0x2a6f3b,
///   icon: "bolt.fill",
///   currentPage: $page,
///   nextPage: "ReactionTime"
/// )
/// .buttonStyle(PressableButtonStyle())
/// ```
///
/// - Important: `color` expects a hex integer (e.g. `0xcfaa51`) used by
///   your custom `Color(hex:)` initializer.
struct SquareButton: View {
    var label: String
    var color: UInt
    var icon: String
    @Binding var currentPage: String
    var nextPage: String
    
    var body: some View {
        Button {
            currentPage = nextPage
        } label: {
            VStack(spacing: 10) {
                Image(systemName: icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 40, height: 40)
                    .foregroundColor(.white)
                Text(label)
                    .font(.system(size: 22, design: .rounded))
                    .foregroundColor(.white)
                
            }
            .frame(width: 150, height: 150) // Fixed square
            .background(Color(hex: color))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.25), radius: 5, x: 2, y: 2)
            .multilineTextAlignment(.center)
        }
        
        .buttonStyle(PressableButtonStyle())
    }
   
}

/// A full-width, rounded rectangular navigation button with icon, title,
/// and an optional description.
///
/// The height adapts based on whether `desc` is empty. Tapping sets
/// `currentPage` to `nextPage` to drive navigation.
///
/// ### Example
/// ```swift
/// GameButton(
///   label: "Verbal Memory",
///   desc: "Remember words; avoid repeats.",
///   color: 0x3b5e7a,
///   icon: "verbalMemoryIcon", // asset catalog image name
///   currentPage: $page,
///   nextPage: "VerbalMemory"
/// )
/// ```
///
/// - Note: `icon` is loaded from asset catalogs (not SF Symbols).
struct GameButton: View {
    var label: String
    var desc: String
    var color: UInt
    var icon: String
    @Binding var currentPage: String
    var nextPage: String
    
    private var buttonHeight: CGFloat {
            desc.isEmpty ? 100 : 120
        }
    
    var body: some View {
        Button {
            currentPage = nextPage
        } label: {
            VStack(spacing: 5) {
                Image(icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 40, height: 40)
                    .foregroundColor(.white)
                Text(label)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                if !desc.isEmpty {
                    Text(desc)
                        .font(.system(size: 16, design: .rounded))
                        .foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity, minHeight: buttonHeight, maxHeight: buttonHeight)
            .background(Color(hex: color))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.25), radius: 5, x: 2, y: 2)
            .multilineTextAlignment(.center)
        }
        .buttonStyle(PressableButtonStyle())
    }
   
}

/// A prominent call-to-action button used to start gameplay or proceed.
///
/// Renders a full-width rounded rectangle with a fixed height and
/// a theme color. Tapping sets `currentPage` to `nextPage`.
///
/// ### Example
/// ```swift
/// PlayButton(label: "Play", currentPage: $page, nextPage: "GameScene")
///   .buttonStyle(PressableButtonStyle())
/// ```
///
/// - Note: This control currently uses a fixed height of 100pt and a
///   hard-coded background color (`0xcfaa51`).
struct PlayButton: View {
    var label: String
    @Binding var currentPage: String
    var nextPage: String
    
    private var buttonHeight = 100
    
    init(label: String, currentPage: Binding<String>, nextPage: String) {
            self.label = label
            self._currentPage = currentPage
            self.nextPage = nextPage
        }
    
    var body: some View {
        Button {
            currentPage = nextPage
        } label: {
            VStack(spacing: 5) {
                Text(label)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity, minHeight: CGFloat(buttonHeight), maxHeight: CGFloat(buttonHeight))
            .background(Color(hex: 0xcfaa51))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.25), radius: 5, x: 2, y: 2)
            .multilineTextAlignment(.center)
        }
        .buttonStyle(PressableButtonStyle())
    }
   
}

