
//
//  ReflexMeter.swift
//  Reflexo
//
//  Created by Asmiya Hasan on 13/10/2025.
//

import SwiftUI

/// A reusable, circular **performance gauge** with an animated sweep,
/// tiered colours (low/mid/high), optional tick marks, and center labels.
///
/// Supply a `0…1` normalized `value` and the meter renders a 240° arc
/// from ~7 o’clock to ~1 o’clock. The end-cap knob and a soft glow
/// provide a polished, game-like feel.
///
/// - Important: `value` is clamped to `0…1`.
/// - Note: The view **does not** paint a background; parent views control
///   background colour (useful for state-driven screens).
///
public struct ReflexMeter: View {
    /// Tier colours for the meter.
    ///
    /// Values below ~34% use `low`, between ~34–67% use `mid`,
    /// and above ~67% use `high`.
    public struct Tiers {
        public var low: Color
        public var mid: Color
        public var high: Color
        public init(low: Color = .red, mid: Color = .yellow, high: Color = .green) {
            self.low = low; self.mid = mid; self.high = high
        }
    }
    
    // MARK: - Inputs

    /// Normalized progress (`0…1`) that drives the sweep.
    @Binding private var value: Double // 0...1
    
    private let title: String
    private let label: String
    private let subtitle: String?
    private let tiers: Tiers
    private let showTicks: Bool
    
    // Style
    private let lineWidth: CGFloat = 16
    
    /// Creates a circular meter.
    ///
    /// - Parameters:
    ///   - value: Normalized progress binding in `0…1`.
    ///   - title: Small caption inside the meter.
    ///   - label: Prominent value text inside the meter.
    ///   - subtitle: Optional helper text inside the meter.
    ///   - tiers: Tier colours (low/mid/high). Defaults to red/yellow/green.
    ///   - showTicks: Whether to render tick marks (default: `true`).
    public init(
        value: Binding<Double>,
        title: String,
        label: String,
        subtitle: String? = nil,
        tiers: Tiers = .init(),
        showTicks: Bool = true
    ) {
        self._value = value
        self.title = title
        self.label = label
        self.subtitle = subtitle
        self.tiers = tiers
        self.showTicks = showTicks
    }
    
    // MARK: - View
    public var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let radius = (size - lineWidth) / 2
            let startDeg: Double = -210     // ~7 o’clock
            let endDeg: Double   =  30      // ~1 o’clock
            let sweepDeg = endDeg - startDeg    // 240°
            let progressDeg = startDeg + sweepDeg * value.clamped
            
            ZStack {
                // Background color is provided by parent. This draws only the gauge.
                // Track (270° * 0.75 = 202.5°, but we want a tidy 240°)
                Circle()
                    .trim(from: 0, to: 2/3) // 240° of 360°
                    .stroke(style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .foregroundStyle(.white.opacity(0.18))
                    .rotationEffect(.degrees(150)) // align to -210°
                    .shadow(color: .black.opacity(0.05), radius: 1, y: 1)
                
                if showTicks {
                    tickMarks(size: size, outerOffset: lineWidth/2 - 1, tickCount: 30)
                        .stroke(.white.opacity(0.16), lineWidth: 1)
                }
                
                // Progress arc
                progressArc(size: size, startDeg: startDeg, progressDeg: progressDeg)
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [tiers.low, tiers.mid, tiers.high]),
                            center: .center,
                            startAngle: .degrees(startDeg),
                            endAngle: .degrees(endDeg)
                        ),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                    .shadow(color: tierColor.opacity(0.7), radius: 16)
                
                // Knob at the end
                Circle()
                    .fill(tierColor)
                    .frame(width: lineWidth, height: lineWidth)
                    .position( // convert polar→cartesian
                        x: geo.size.width/2 + radius * CGFloat(cos(progressDeg.radians)),
                        y: geo.size.height/2 + radius * CGFloat(sin(progressDeg.radians))
                    )
                    .overlay(Circle().stroke(.white.opacity(0.4), lineWidth: 1))
                    .shadow(color: tierColor.opacity(0.6), radius: 8)
                    .allowsHitTesting(false)
                
                // Center text
                VStack(spacing: 4) {
                    Text(title)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.white.opacity(0.75))
                    Text(label)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    if let subtitle {
                        Text(subtitle)
                            .font(.system(.footnote, design: .rounded))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }
                .multilineTextAlignment(.center)
            }
            .frame(width: size, height: size)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(title))
            .accessibilityValue(Text("\(Int(value.clamped * 100)) percent"))
            .animation(.easeInOut(duration: 0.8), value: value)
        }
        .aspectRatio(1, contentMode: .fit)
    }
    
    // MARK: - Computed

    /// Current tier colour based on the clamped progress.
    private var tierColor: Color {
        switch value.clamped {
        case ..<0.34: return tiers.low
        case ..<0.67: return tiers.mid
        default:      return tiers.high
        }
    }
    
    // MARK: - Drawing

    /// Builds the progress arc path for the given sweep.
    ///
    /// - Parameters:
    ///   - size: Square drawing size.
    ///   - startDeg: Start angle in degrees.
    ///   - progressDeg: End angle in degrees based on current progress.
    private func progressArc(size: CGFloat, startDeg: Double, progressDeg: Double) -> Path {
        let rect = CGRect(x: (size - size)/2, y: (size - size)/2, width: size, height: size)
        var p = Path()
        p.addArc(center: CGPoint(x: size/2, y: size/2),
                 radius: (size - lineWidth)/2,
                 startAngle: .degrees(startDeg),
                 endAngle: .degrees(progressDeg),
                 clockwise: false)
        return p
    }
    
    /// Builds radial tick marks along the meter’s sweep.
    ///
    /// - Parameters:
    ///   - size: Square drawing size.
    ///   - outerOffset: Extra outward offset from the ring for visual separation.
    ///   - tickCount: Number of ticks to render.
    private func tickMarks(size: CGFloat, outerOffset: CGFloat, tickCount: Int) -> Path {
        let center = CGPoint(x: size/2, y: size/2)
        let radius = (size - lineWidth)/2 + outerOffset
        var p = Path()
        for i in 0..<tickCount {
            let t = Double(i) / Double(tickCount - 1)           // 0…1
            let deg = -210 + 240 * t
            let dir = CGPoint(x: cos(deg.radians), y: sin(deg.radians))
            let p1 = CGPoint(x: center.x + dir.x * (radius - 6),
                             y: center.y + dir.y * (radius - 6))
            let p2 = CGPoint(x: center.x + dir.x * radius,
                             y: center.y + dir.y * radius)
            p.move(to: p1)
            p.addLine(to: p2)
        }
        return p
    }
}

// MARK: - Utils
private extension Double {
    var clamped: Double { min(1, max(0, self)) }
    var radians: Double { self * .pi / 180 }
}
