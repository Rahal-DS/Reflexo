//
//  AimTrainerView.swift
//  Reflexo
//
//  Created by Rahal De Silva on 09/10/2025.
//

import SwiftUI

/// The SwiftUI screen for the **Aim Trainer** mini-game.
///
/// `AimTrainerView` renders a playfield where circular targets appear
/// and the player attempts to tap them quickly and accurately. It shows:
/// - a header with the game title and live metrics (time/accuracy),
/// - a responsive playfield that registers hits and misses,
/// - a footer with primary/secondary actions (Start / Play Again / Back).
///
/// The view owns an ``AimTrainerViewModel`` and attaches a `modelContext`
/// for local persistence (e.g., attempts or best scores).
///
/// ### Usage
/// ```swift
/// @State private var page = "Games"
/// AimTrainerView(currentPage: $page)
///     .environmentObject(FirebaseManager.shared)
/// ```
///
/// - Important: The view model’s `startGame(in:)` expects the **playfield size**.
///   In production, pass the actual `GeometryReader` size rather than a fixed size.
struct AimTrainerView: View {
    /// The current navigation page (bound to parent coordinator/router).
    @Binding var currentPage: String
    
    /// Game logic and state container.
    @StateObject private var vm = AimTrainerViewModel()
    
    /// SwiftData model context used by the view model for persistence.
    @Environment(\.modelContext) private var modelContext
    
    /// The nominal outer ring size for targets (currently unused here but kept for design parity).
    private let ringSize: CGFloat = 64
    
    var body: some View {
        ZStack {
            Color("DarkOlive").ignoresSafeArea()
            
            VStack(spacing: 16) {
                header
                GeometryReader { geo in playfield(size: geo.size) }
                footer
            }
            .padding(.horizontal, 20)
            .padding(.top, 50)
            .padding(.bottom, 28)
        }
        .onAppear{
            vm.attach(modelContext: modelContext)
        }
    }
    
    
    private var header: some View {
        VStack(spacing: 6) {
            Text("Aim Trainer")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.top, 50)
            if (vm.isRunning)
            {
                HStack(spacing: 14) {
                    Text(timeString(vm.elapsed))
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.9))
                }
            }
            else
            {
                Text("Tap or Swipe all the targets as fast as you can!")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
        }
    }
    
    // MARK: - Playfield

    /// The interactive playfield where targets are drawn and tapped.
    ///
    /// - Parameter size: The available size from `GeometryReader` used for target layout.
    ///
    /// Tapping the background registers a **miss** while the game is running.
    /// Each target is a tappable circle whose fill color reflects its state.
    @ViewBuilder
    private func playfield(size: CGSize) -> some View {
        ZStack {
            Color.clear
                .contentShape(Rectangle())
                .gesture(
                    SimultaneousGesture(
                        TapGesture(count: 2)
                            .onEnded { _ in
                                vm.startCombo()
                            },
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                vm.dragHit(at: value.location)
                            }
                            .onEnded { _ in
                                vm.endCombo()   
                            }
                    )
                )

            ForEach(vm.targets) { target in
                Circle()
                    .fill(target.hit ? .gray : .red)
                    .frame(width: vm.targetRadius * 2, height: vm.targetRadius * 2)
                    .position(target.position)
                    .onTapGesture {
                        if !vm.comboActive {
                            vm.hitTarget(id: target.id)
                        }
                    }
                    .animation(.easeOut(duration: 0.25), value: target.scale)
                    .animation(.easeOut(duration: 0.15), value: target.hit)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(vm.comboActive ? Color.yellow.opacity(0.8) : Color.white.opacity(0.08),
                        lineWidth: vm.comboActive ? 4 : 1)
                .animation(.easeInOut(duration: 0.2), value: vm.comboActive)
        )


    }


    private var footer: some View {
        Group {
            if vm.gameOver {
                VStack(spacing: 10) {
                    Text("Finished in \(timeString(vm.elapsed))")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    HStack(spacing: 12) {
                        primaryButton("Play Again") {
                            DispatchQueue.main.async {
                                vm.startGame(in: CGSize(width: 360, height: 600))
                            }
                        }
                        secondaryButton("Back") { currentPage = "Games" }
                    }
                }
            }
            else
            {
                HStack(spacing: 12)
                {
                    primaryButton("Start") {
                        if !vm.isRunning {
                            vm.startGame(in: CGSize(width: 360, height: 600))
                        }
                    }
                    .disabled(vm.isRunning)
                    .opacity(vm.isRunning ? 0.5 : 1.0)

                    
                }
            }
        }
    }
    
    // MARK: - Buttons

    /// A filled, capsule-shaped primary action button.
    ///
    /// - Parameters:
    ///   - title: The button title.
    ///   - action: Action invoked on tap.
    private func primaryButton(
        _ title: String,
        action: @escaping () -> Void) -> some View {
            Button(action: action)
            {
                Text(title)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.black)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 20)
                    .background(.white)
                    .clipShape(Capsule())
                    .shadow(radius: 4, y: 2)
            }
            .buttonStyle(.plain)
        }
    
    /// An outlined, capsule-shaped secondary action button.
    ///
    /// - Parameters:
    ///   - title: The button title.
    ///   - action: Action invoked on tap.
    private func secondaryButton(
        _ title: String,
        action: @escaping () -> Void) -> some View {
            Button(action: action)
            {
                Text(title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 14)
                    .overlay(Capsule().stroke(.white.opacity(0.8), lineWidth: 1))
            }
            .buttonStyle(.plain) }
    
    // MARK: - Formatting

    /// Formats a duration in seconds into `m:ss.ff` (minutes:seconds.centiseconds).
    ///
    /// - Parameter seconds: The duration to format.
    /// - Returns: A string like `"0:12.34"`.
    private func timeString(_ seconds: TimeInterval) -> String
    {
        let totalMs = Int((seconds * 1000).rounded())
        let mins = totalMs / 60000
        let secs = (totalMs % 60000) / 1000
        let ms   = totalMs % 1000 / 10
        return String(format: "%d:%02d.%02d", mins, secs, ms)
    }
}

//#Preview {
//    AimTrainerView(currentPage: .constant("Games"))
//        .environmentObject(FirebaseManager.shared)
//}

