//
//  ReactionTimeView.swift
//  Reflexo
//
//  Created by Asmiya Hasan on 15/9/2025.


import SwiftUI


/// A SwiftUI screen for the **Reaction Time** mini-game.
///
/// The view runs a single-round **Idle → Waiting (red) → Ready (green) → Result**
/// loop controlled by ``ReactionTimeViewModel``. A transparent, full-screen
/// tap catcher is enabled selectively so premature taps are detected during **Waiting**.
///
/// ### Responsibilities
/// - Presents instructions, live status (best time), and the round result.
/// - Animates the background color across states.
/// - Forwards taps to ``ReactionTimeViewModel/handleTap()`` only when appropriate.
/// - Provides primary/secondary controls to start and retry rounds.
///
/// ### State Machine
/// - ``ReactionTimeViewModel.State/idle``: Instructions + Start.
/// - ``ReactionTimeViewModel.State/waiting`` (red): Arms taps after a short delay; taps here trigger **tooSoon**.
/// - ``ReactionTimeViewModel.State/ready`` (green): First tap records reaction time → **result**.
/// - ``ReactionTimeViewModel.State/tooSoon``: Feedback + Try Again.
/// - ``ReactionTimeViewModel.State/result(ms:)``: Shows round latency + best.
///
struct ReactionTimeGameView: View {
    @Binding var currentPage: String
    @StateObject private var vm = ReactionTimeViewModel()
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        ZStack {
            backgroundColor
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.15), value: vm.state)
            
            VStack(spacing: 16) {
                header
                Spacer(minLength: 0)
                mainContent
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                Spacer(minLength: 0)
                bottomBar
                    .padding(.horizontal, 24)
            }
            .padding(.top, 20)
            .padding(.bottom, 28)
            
            // Transparent full-screen tap catcher
            Color.clear
                .contentShape(Rectangle())
                .allowsHitTesting(tapEnabled)     // <-- only active when we want it
                .onTapGesture { vm.handleTap() }
        }
        .onDisappear { vm.cancelDelay() }
    }
    
    /// Whether the transparent tap layer should accept taps for current state.
    ///
    /// Enabled during **waiting** and **ready** (when ``ReactionTimeViewModel/tapArmed`` is true).
    private var tapEnabled: Bool {
        switch vm.state {
        case .waiting, .ready: return vm.tapArmed
        default: return false
        }
    }
    
    // MARK: - UI

    /// The header shows the game title and the saved best reaction time if available.
    ///
    /// Also attaches the model context and triggers view-model on-appear hooks.
    private var header: some View {
        VStack(spacing: 6) {
            Text("Reaction Time")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.top, 50)
            if vm.bestMs != .max {
                Text("Best: \(vm.bestMs) ms")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
        .onAppear {
            vm.onAppear()
            vm.attach(modelContext: modelContext)
            vm.dumpAllAttemptsToConsole(ctx: modelContext)
        }
        
    }
    
    /// State-driven center content (instructions, prompts, or results).
    @ViewBuilder
    private var mainContent: some View {
        switch vm.state {
        case .idle:
            Text("When you tap **Start**, the screen turns **red**.\n\nWait until it turns **green**, then tap as fast as you can!")
                .font(.system(size: 18, weight: .regular, design: .rounded))
                .foregroundStyle(.white)
            
        case .waiting:
            Text("Wait for **green**…")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            
        case .ready:
            Text("TAP!")
                .font(.system(size: 48, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
            
        case .tooSoon:
            Text("Too soon! 👀\nWait for **green** next time.")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            
        case .result(let ms):
            VStack(spacing: 16) {
                AnimatedResultMeter(ms: ms, bestMs: 180, worstMs: 450)
                    .frame(height: 260)

                if vm.bestMs != .max {
                    Text("Best: \(vm.bestMs) ms")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.85))
                }
            }
        }
    }
    
    /// Bottom controls vary by state: Start/Retry/Home
    @ViewBuilder
    private var bottomBar: some View {
        switch vm.state {
        case .idle:
            HStack(spacing: 12) {
                primaryButton(title: "Start") { vm.startRound() }
                secondaryButton(title: "Home") { currentPage = "Home" }
            }
            
        case .waiting, .ready:
            Text("Tap anywhere")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))
            
        case .tooSoon, .result:
            HStack(spacing: 12) {
                primaryButton(title: "Try Again") { vm.startRound() }
                secondaryButton(title: "Home") {currentPage = "Home"}
            }
        }
    }
    
    // MARK: - Buttons

    /// A prominent primary action button used for Start/Try Again.
    ///
    /// - Parameters:
    ///   - title: Button label.
    ///   - action: Action to run on tap.
    /// - Returns: A capsule-like, bold, high-contrast button.
    private func primaryButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(radius: 4, y: 2)
        }
        .buttonStyle(.plain)
    }
    
    /// A secondary, outlined button used for navigation (e.g., Home).
    ///
    /// - Parameters:
    ///   - title: Button label.
    ///   - action: Action to run on tap.
    /// - Returns: An outlined button with rounded rectangle shape.
    private func secondaryButton(title: String, action: @escaping () -> Void) -> some View {
        Button(role: .destructive, action: action) {
            Text(title)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 56)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(.white.opacity(0.75), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
    
    private var backgroundColor: Color {
        switch vm.state {
        case .idle:    return Color("DarkOlive")
        case .waiting: return .red
        case .ready:   return .green
        case .tooSoon: return .orange
        case .result:  return Color(.sRGB, red: 0.10, green: 0.50, blue: 0.28, opacity: 1.0)
        }
    }
}

/// An animated wrapper that reveals the ``ReactionReflexMeter``
/// by interpolating a local `shownMs` from `0` → `ms` on appear.
///
/// Use this in the `result(ms:)` state to add a satisfying, polished reveal.
///
/// - Parameters:
///   - ms: The measured latency for the finished round (milliseconds).
///   - bestMs: Mapping bound considered **excellent** (progress = 1.0).
///   - worstMs: Mapping bound considered **poor** (progress = 0.0).
private struct AnimatedResultMeter: View {
    let ms: Int
    let bestMs: Double
    let worstMs: Double

    @State private var shownMs: Int = 0

    var body: some View {
        ReactionReflexMeter(ms: $shownMs, bestMs: bestMs, worstMs: worstMs, title: "Reaction Time")
            .onAppear {
                withAnimation(.easeInOut(duration: 0.6)) {
                    shownMs = ms
                }
            }
    }
}

//#Preview {
//    ReactionTimeGameView(currentPage: .constant("Games"))
//        .environmentObject(FirebaseManager.shared)
//}
