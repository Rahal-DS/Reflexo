//
//  VerbalMemoryView.swift
//  Reflexo
//
//  Created by Asmiya Hasan on 12/10/2025.
//
import SwiftUI

/// A SwiftUI screen for the **Verbal Memory** mini-game.
///
/// The game streams words from a ``RandomWordService`` via
/// ``VerbalMemoryViewModel``. The user decides if each word has been
/// seen before (**Seen**) or not (**Unseen**). Each correct answer
/// increases the score; mistakes consume one of three lives.
///
/// ### Flow
/// - ``VerbalMemoryViewModel.State/idle`` → instructions and **Start**
/// - ``VerbalMemoryViewModel.State/loading`` → prefetching/caching words
/// - ``VerbalMemoryViewModel.State/playing`` → answer with **Seen/Unseen**
/// - ``VerbalMemoryViewModel.State/gameOver`` → score summary + restart
/// - ``VerbalMemoryViewModel.State/error(_:)`` → user-visible error + retry
///
/// ### Responsibilities
/// - Presents the header (title, lives, score)
/// - Shows the current word and meta (unique seen count)
/// - Routes button taps to the view model
/// - Attaches SwiftData `modelContext` for persistence/sync
///
/// ### Usage
/// ```swift
/// VerbalMemoryView(currentPage: $router.page)
///     .environmentObject(FirebaseScoresManager.shared) // scores upload/cache
/// ```
///
///
struct VerbalMemoryView: View {
    @Binding var currentPage: String
    @StateObject private var vm: VerbalMemoryViewModel
    @EnvironmentObject var fbScores: FirebaseScoresManager
    @Environment(\.modelContext) private var modelContext
    
    /// Creates a Verbal Memory screen.
    ///
    /// - Parameters:
    ///   - currentPage: Binding to the parent router/page.
    ///   - service: Word provider; defaults to a network-backed implementation.
    init(currentPage: Binding<String>,
         service: RandomWordService = RandomWordAPIService()) {
        self._currentPage = currentPage
        _vm = StateObject(wrappedValue: VerbalMemoryViewModel(service: service, cacheSize: 50))
    }
    
    var body: some View {
        ZStack {
            Color("DarkOlive")
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
        }
        .onAppear {
            vm.attach(modelContext: modelContext)
        }
    }
    
    // MARK: - UI
    
    private var header: some View {
        VStack(spacing: 6) {
            Text("Verbal Memory")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.top, 50)
            
            HStack(spacing: 14) {
                // Lives
                HStack(spacing: 6) {
                    ForEach(0..<3, id: \.self) { i in
                        Image(systemName: i < vm.lives ? "heart.fill" : "heart")
                            .imageScale(.large)
                            .foregroundStyle(.white)
                    }
                }
                
                Spacer(minLength: 0)
                
                // Score
                Text("Score: \(vm.score)")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
            }
            .padding(.horizontal, 24)
        }
    }
    
    /// Center content varies by game state (instructions, loading, word prompt, result, or error).
    @ViewBuilder
    private var mainContent: some View {
        switch vm.state {
        case .idle:
            VStack(spacing: 16) {
                Text("How to Play")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                
                Text("Tap **Start** to begin. If the word has appeared before, choose **Seen**; otherwise choose **Unseen**. You have **3 lives**. +1 point for each correct answer.")
                    .font(.system(size: 16, weight: .regular, design: .rounded))
                    .foregroundStyle(.white.opacity(0.95))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 36)
            .padding(.horizontal, 16)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            
        case .loading:
            VStack(spacing: 16) {
                ProgressView("Fetching words...")
                    .tint(.white)
                Text("Preparing your word list…")
                    .font(.system(size: 16, weight: .regular, design: .rounded))
                    .foregroundStyle(.white.opacity(0.95))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 36)
            .padding(.horizontal, 16)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            
        case .playing:
            VStack(spacing: 14) {
                Text(vm.currentWord)
                    .font(.system(size: 44, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                
                Text("Seen \(vm.seenCount) unique")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.8))
                
                VerbalLiveMeter(score: vm.score, target: max(vm.bestScore, 30))
                    .frame(height: 140)
                    .padding(.top, 6)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
            .padding(.horizontal, 16)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            
        case .gameOver:
            VStack(spacing: 16) {
                Text("Game Over")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                // Animated meter
                AnimatedVerbalResultMeter(
                    score: vm.score,
                    target: max(vm.bestScore, vm.score, 30) // pick a target that makes sense for your app
                )
                .frame(height: 260)

                Text("Final Score: \(vm.score)")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.95))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .padding(.horizontal, 16)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            
        case .error(let msg):
            VStack(spacing: 12) {
                Text("Error")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(msg)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.95))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 28)
            .padding(.horizontal, 16)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
    }
    
    @ViewBuilder
    private var bottomBar: some View {
        switch vm.state {
        case .idle:
            HStack(spacing: 12) {
                primaryButton(title: "Start") { vm.startGame() }
                secondaryButton(title: "Home") { currentPage = "Home" }
            }
            
        case .loading:
            EmptyView()
            
        case .playing:
            HStack(spacing: 12) {
                choiceButton(title: "Unseen", bg: "MediumYellow") {vm.chooseUnseen()}
                choiceButton(title: "Seen", bg: "Olive") {vm.chooseSeen()}
            }
            
        case .gameOver:
            HStack(spacing: 12) {
                primaryButton(title: "Play Again") { vm.restart() }
                secondaryButton(title: "Home") { currentPage = "Home" }
            }
            
        case .error:
            HStack(spacing: 12) {
                primaryButton(title: "Try Again") { vm.restart() }
                secondaryButton(title: "Back") { currentPage = "Home" }
            }
        }
    }
    
    // MARK: - Buttons

    /// Primary filled button used for Start/Play Again/Try Again.
    ///
    /// - Parameters:
    ///   - title: Button label.
    ///   - action: Callback invoked on tap.
    
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
    
    private func secondaryButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
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
    
    /// Choice button for **Seen/Unseen** during gameplay.
    ///
    /// - Parameters:
    ///   - title: Button label (e.g., "Seen", "Unseen").
    ///   - bg: Named color in the asset catalog.
    ///   - action: Callback invoked on tap.
    private func choiceButton(title: String, bg: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(Color(bg))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(radius: 4, y: 2)
        }
        .buttonStyle(.plain)
    }
}
// MARK: - Meter helpers

/// Animated wrapper that reveals the ``VerbalReflexMeter`` by interpolating
/// a local score from `0` → final `score` on appear.
///
/// Use this in the `gameOver` state to add a polished finish to the round summary.
///
/// - Parameters:
///   - score: The final score for the finished round.
///   - target: The score treated as 100% (e.g., personal best or milestone).
private struct AnimatedVerbalResultMeter: View {
    let score: Int
    let target: Int

    @State private var shown: Int = 0

    var body: some View {
        VerbalReflexMeter(score: $shown, target: target, title: "Verbal Memory")
            .onAppear {
                // smooth 0 → score reveal
                withAnimation(.easeInOut(duration: 0.6)) {
                    shown = score
                }
            }
    }
}
/// Compact live meter shown during play, reflecting progress toward `target`.
///
/// - Parameters:
///   - score: Current in-round score.
///   - target: The score treated as 100% (e.g., best or rubric cap).
private struct VerbalLiveMeter: View {
    let score: Int
    let target: Int
    @State private var boundScore: Int = 0
    var body: some View {
        VerbalReflexMeter(score: $boundScore, target: target, title: "Progress")
            .onAppear { boundScore = score }
            .onChange(of: score) { _, new in
                withAnimation(.easeInOut(duration: 0.35)) { boundScore = new }
            }
    }
}


//#Preview {
//    VerbalMemoryView(currentPage: .constant("Games"))
//        .environmentObject(FirebaseManager.shared)
//}
