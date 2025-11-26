//
//  VerbalReflexMeter.swift
//  Reflexo
//
//  Created by Asmiya Hasan on 13/10/2025.
//

import SwiftUI

/// A convenience wrapper for **higher-is-better** scores (e.g., Verbal Memory).
/// Maps `score` to 0…1 using a chosen `target` (e.g., your best or a milestone).
public struct VerbalReflexMeter: View {
    @Binding var score: Int
    @State private var progress: Double = 0

    /// A score that maps to 100%. Use best-ever, personal target, or a course rubric cap.
    let target: Int
    let title: String

    public init(score: Binding<Int>, target: Int = 30, title: String = "Verbal Memory") {
        self._score = score
        self.target = max(1, target) // avoid divide-by-zero
        self.title = title
    }

    public var body: some View {
        ReflexMeter(
            value: $progress,
            title: title,
            label: "\(score)",
            subtitle: subtitle(for: progress),
            tiers: .init(low: .red.opacity(0.95), mid: .yellow.opacity(0.95), high: .green.opacity(0.95)),
            showTicks: true
        )
        .onChange(of: score) { _, new in
            withAnimation(.easeInOut(duration: 0.8)) {
                progress = min(1, Double(new) / Double(target))
            }
        }
        .task {
            progress = min(1, Double(score) / Double(target))
        }
        .accessibilityLabel(Text(title))
        .accessibilityValue(Text("\(Int(progress * 100)) percent"))
    }

    private func subtitle(for p: Double) -> String {
        switch p {
        case ..<0.34: return "warming up"
        case ..<0.67: return "solid"
        default:      return "great"
        }
    }
}
