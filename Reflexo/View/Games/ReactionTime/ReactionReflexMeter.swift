//
//  ReactionReflexMeter.swift
//  Reflexo
//
//  Created by Asmiya Hasan on 13/10/2025.
//

import SwiftUI
import CoreHaptics

/// A circular, animated meter for **reaction time** results.
///
/// `ReactionReflexMeter` wraps ``ReflexMeter`` and converts a measured latency in
/// milliseconds (where **lower is better**) into a normalized progress value in `0…1`.
/// It also provides tier text (e.g., “needs work” / “solid” / “great”) and optional
/// haptic feedback when the displayed value changes.
///
/// - Important: `bestMs` maps to **progress = 1.0** and `worstMs` maps to **progress = 0.0**.
///   Values outside the range are clamped before mapping.
/// - Note: Haptics require a supported device. The iOS Simulator will skip haptic playback.
/// - SeeAlso: ``ReflexMeter``
public struct ReactionReflexMeter: View {
    /// The measured reaction time for the round (milliseconds).
    @Binding var ms: Int
    
    /// Internal normalized progress (`0…1`) derived from `ms`.
    @State private var progress: Double = 0

    /// The **excellent** bound (in ms). Values at or better than this map to `1.0`.
    let bestMs: Double
    
    /// The **poor** bound (in ms). Values at or worse than this map to `0.0`.
    let worstMs: Double
    
    /// Title displayed in the center of the meter (e.g., “Reaction”).
    let title: String

    
    // MARK: - Init

    /// Creates a reaction-time meter.
    ///
    /// - Parameters:
    ///   - ms: The current reaction time (milliseconds) to visualize.
    ///   - bestMs: The “excellent” bound (default: `180`). Lower or equal maps to `1.0`.
    ///   - worstMs: The “poor” bound (default: `450`). Higher or equal maps to `0.0`.
    ///   - title: Center title string (default: `"Reaction"`).
    public init(
        ms: Binding<Int>,
        bestMs: Double = 180,
        worstMs: Double = 450,
        title: String = "Reaction"
    ) {
        self._ms = ms
        self.bestMs = bestMs
        self.worstMs = worstMs
        self.title = title
    }

    // MARK: - View
    public var body: some View {
        ReflexMeter(
            value: $progress,
            title: title,
            label: "\(ms) ms",
            subtitle: tierText(for: progress),
            tiers: .init(
                low: .red.opacity(0.95),
                mid: .yellow.opacity(0.95),
                high: .green.opacity(0.95)
            ),
            showTicks: true
        )
        .onChange(of: ms) { _, new in
            let p = normalized(ms: Double(new))
            withAnimation(.easeInOut(duration: 0.8)) { progress = p }
        }
        .task {
            progress = normalized(ms: Double(ms))
        }
    }

    // MARK: - Mapping

    /// Maps a measured latency to a normalized progress value.
    ///
    /// - Parameter ms: Measured milliseconds.
    /// - Returns: A value in `0…1` where `bestMs → 1.0` and `worstMs → 0.0`.
    private func normalized(ms: Double) -> Double {
        // Clamp and map worst->0, best->1
        let clamped = max(bestMs, min(worstMs, ms))
        return 1 - ((clamped - bestMs) / (worstMs - bestMs))
    }

    // MARK: - Mapping

    /// Maps a measured latency to a normalized progress value.
    ///
    /// - Parameter ms: Measured milliseconds.
    /// - Returns: A value in `0…1` where `bestMs → 1.0` and `worstMs → 0.0`.
    private func tierText(for p: Double) -> String {
        switch p {
        case ..<0.34: return "needs work"
        case ..<0.67: return "solid"
        default:      return "great"
        }
    }
}
