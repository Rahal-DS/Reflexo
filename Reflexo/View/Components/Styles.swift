//
//  Helpers.swift
//  Reflexo
//
//  Created by Asmiya Hasan on 31/8/2025.
//

import SwiftUI

// MARK: - Color(hex:) initializer

/// Convenience initializer for creating `Color` values from a 24-bit hex RGB integer.
///
/// The initializer expects a hex value in the form `0xRRGGBB`. An optional
/// `alpha` parameter controls opacity.
///
/// ### Examples
/// ```swift
/// let accent = Color(hex: 0xcfaa51)              // opaque
/// let overlay = Color(hex: 0x000000, alpha: 0.3) // 30% black
/// ```
///
/// - Parameters:
///   - hex: A 24-bit RGB hex integer (e.g., `0x1A2B3C`).
///   - alpha: Opacity from `0.0` (transparent) to `1.0` (opaque). Default is `1.0`.
extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 08) & 0xff) / 255,
            blue: Double((hex >> 00) & 0xff) / 255,
            opacity: alpha
        )
    }
}

// MARK: - HeaderView

/// A reusable, centered title header with Reflexo’s brand styling.
///
/// Renders a bold rounded title, colored with the `DarkYellow` asset,
/// with gentle letter-spacing, multiline support, and comfortable padding.
///
/// ### Example
/// ```swift
/// VStack {
///     HeaderView(title: "Verbal Memory Leaderboard")
///     // content...
/// }
/// ```
///
/// - Important: The color asset `"DarkYellow"` must exist in your asset catalog.
struct HeaderView: View {
    var title: String
    
    var body: some View {
        Text(title)
            .font(.system(size: 32, weight: .bold, design: .rounded))
            .foregroundColor(Color("DarkYellow"))
            .tracking(2) // optional letter spacing
            .multilineTextAlignment(.center)  // center text if it wraps
            .lineLimit(nil)                   // allow multiple lines
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 20)
            .padding(.horizontal, 80) // margin on sides
        
    }
}
// MARK: - DisplayScore

/// A compact, pill-shaped leaderboard row with rank, player name, and score.
///
/// Suited for dense lists where you want prominent color theming.
/// Text is truncated where necessary, and the row has a consistent height.
///
/// ### Example
/// ```swift
/// DisplayScore(
///   ranking: "#1",
///   name: "asmiyahasan",
///   score: "245 ms",
///   color: 0x3A6F55
/// )
/// .padding(.horizontal)
/// ```
///
/// - Parameters:
///   - ranking: Rank indicator (e.g., `#1`, `2`, `T-3`).
///   - name: Player display name; long names are truncated with an ellipsis.
///   - score: Score string formatted for display (e.g., `"245 ms"`).
///   - color: Hex RGB for background (via ``Color/init(hex:alpha:)``).
///
/// - Note: Consider adding `.accessibilityLabel("\(ranking), \(name), score \(score)")`
///   in contexts where VoiceOver summaries are preferred.
struct DisplayScore: View {
    var ranking: String
    var name: String
    var score: String
    var color: UInt
    

    var body: some View {
            HStack(spacing: 15) {
                Text(ranking)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(width: 50, alignment: .leading)
                Text(name)
                    .font(.system(size: 20, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer()
                Text(score)
                    .font(.system(size: 20, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.trailing)
                    .frame(alignment: .trailing)
                
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(minHeight: 90, maxHeight: 90)
            .background(Color(hex: color))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.25), radius: 5, x: 2, y: 2)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 80)

        }
   
}
// MARK: - AimTrainerDisplayScore

/// A leaderboard row optimized for Aim Trainer’s typically longer scores/labels.
///
/// Uses slightly smaller fonts and a fixed width for the trailing score to
/// improve alignment across rows.
///
/// ### Example
/// ```swift
/// AimTrainerDisplayScore(
///   ranking: "12",
///   name: "swift_ninja",
///   score: "Accuracy 92% | 47 hits",
///   color: 0x324A6E
/// )
/// ```
///
/// - Note: The trailing score column is constrained to maintain alignment
///   across a list of rows.
struct AimTrainerDisplayScore: View {
    var ranking: String
    var name: String
    var score: String
    var color: UInt
    

    var body: some View {
            HStack(spacing: 15) {
                Text(ranking)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(width: 50, alignment: .leading)
                Text(name)
                    .font(.system(size: 15, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Spacer()
                Text(score)
                    .font(.system(size: 12, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 135, alignment: .trailing)
                
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(minHeight: 100, maxHeight: 100)
            .background(Color(hex: color))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.25), radius: 5, x: 2, y: 2)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 80)

        }
   
}
// MARK: - Card ViewModifier

/// A reusable card appearance for lightweight content containers.
///
/// Applies max width, padding, a translucent white rounded rectangle
/// background, and a soft drop shadow. Useful for quick, consistent
/// styling of informational blocks.
///
/// ### Example
/// ```swift
/// VStack(spacing: 12) {
///     Text("Welcome to Reflexo").font(.headline)
///     Text("Train your reflexes with fun mini-games.")
/// }
/// .card()
/// ```
struct Card: ViewModifier {
    func body(content: Content) -> some View {
        content
            .frame(maxWidth: 300, alignment: .center)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.65))
            )
            .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
    }
}

// MARK: - View.card()

/// Applies the ``Card`` modifier to a view.
///
/// A convenience wrapper to keep call sites concise and self-documenting.
///
/// ### Example
/// ```swift
/// Text("Score saved!")
///   .card()
/// ``
extension View { func card() -> some View { modifier(Card()) } }
