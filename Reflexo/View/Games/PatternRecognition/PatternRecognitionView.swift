//  PatternRecognitionView.swift
//  Reflexo
//
//  Created by Rahal De Silva on 11/10/2025.
//

import SwiftUI

/// A SwiftUI screen for the **Pattern Recognition** mini-game.
///
/// The view renders an _n × n_ grid and drives a short
/// **show → recall → success/fail** loop using a
/// ``PatternRecognitionViewModel``. During **show**, a subset of cells
/// is briefly highlighted; in **recall**, the user reproduces the pattern
/// by tapping the same cells. Success advances the grid size; failure
/// offers a retry.
///
/// ### Responsibilities
/// - Presents header/status text and the dynamic grid.
/// - Forwards taps to ``PatternRecognitionViewModel/tapCell(_:)`` during recall.
/// - Drives progression buttons (Start/Retry/Next/Restart).
///
/// ### Styling
/// Uses the app color palette (e.g. `Color("DarkOlive")`) and rounded,
/// high-contrast controls for accessibility.
///
/// ### Usage
/// Embed in a parent container and bind ``currentPage`` for navigation:
///
/// ```swift
/// PatternRecognitionView(currentPage: $router.page)
///     .environmentObject(firebase)
///
struct PatternRecognitionView: View {
    @Binding var currentPage: String
    @StateObject private var vm = PatternRecognitionViewModel()
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        ZStack {
            Color("DarkOlive").ignoresSafeArea()
            
            VStack(spacing: 20) {
                header
                grid
                footer
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 28)
        }
        .onAppear {
            vm.attach(modelContext: modelContext)
        }
    }
    
    // MARK: - Header
    private var header: some View {
        VStack(spacing: 6) {
            Text("Pattern Recognition")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.top, 50)
            Text(vm.message)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))
                .multilineTextAlignment(.center)
            
            HStack(spacing: 12) {
                Text("Grid: \(vm.gridSize)×\(vm.gridSize)")
            }
            .font(.system(size: 14, weight: .semibold, design: .rounded))
            .foregroundStyle(.white.opacity(0.8))
        }
    }
    
    // MARK: - Grid
    
    /// The interactive grid area that shows the pattern and receives taps during recall.
    ///
    /// The grid:
    /// - Computes a square cell size that fits within the available geometry.
    /// - Highlights cells in **showPattern** using a bright fill.
    /// - Marks user selections in **recall** using an accent fill.
    ///
    /// Taps are only forwarded to the view model when
    /// ``PatternRecognitionViewModel/state`` is ``PatternRecognitionViewModel.State/recall``.
    private var grid: some View {
        GeometryReader { geo in
            let columns = Array(repeating: GridItem(.flexible(), spacing: 8, alignment:.center),count: vm.gridSize)
            let side = min( geo.size.width,geo.size.height ) - 8
            let cell = (side - CGFloat(vm.gridSize - 1) * 8) / CGFloat(vm.gridSize)
            
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(0..<(vm.gridSize * vm.gridSize), id: \.self) { idx in
                    let isShowing = (vm.state == .showPattern) && vm.pattern.contains(idx)
                    let isSelected = (vm.state == .recall) && vm.selection.contains(idx)
                    
                    Rectangle()
                        .fill(cellColor(isShowing: isShowing, isSelected: isSelected))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(.white.opacity(0.15), lineWidth: 1)
                        )
                        .frame(width: cell, height: cell)
                        .cornerRadius(8)
                        .onTapGesture {
                            if vm.state == .recall {
                                vm.tapCell(idx)
                            }
                        }
                        .animation(.easeInOut(duration: 0.2), value: isShowing)
                        .animation(.easeInOut(duration: 0.15), value: isSelected)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .frame(maxHeight: 520)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.08), lineWidth: 1))
    }
    // MARK: - Helpers
    
    /// Resolves a cell’s fill color based on whether it is being shown as part
    /// of the target pattern or is currently selected by the user.
    ///
    /// - Parameters:
    ///   - isShowing: `true` when the cell is part of the pattern during **showPattern**.
    ///   - isSelected: `true` when the user has selected this cell during **recall**.
    /// - Returns: A `Color` appropriate for the current visual state.
    private func cellColor(isShowing: Bool, isSelected: Bool) -> Color {
        if isShowing { return Color.white.opacity(0.9) }
        if isSelected { return Color.blue.opacity(0.9) }
        return Color.white.opacity(0.15)
    }
    
    // MARK: - Footer

    /// Bottom-bar controls that adapt to the game state.
    ///
    /// States:
    /// - ``PatternRecognitionViewModel.State/idle`` & ``PatternRecognitionViewModel.State/gameOver``:
    ///   Show **Start/Retry** and **Back** buttons.
    /// - ``PatternRecognitionViewModel.State/success``:
    ///   Show **Next** (increments grid size up to ``PatternRecognitionViewModel/maxGridSize``)
    ///   or **Restart** (wraps to 4×4).
    /// - ``PatternRecognitionViewModel.State/showPattern`` & ``PatternRecognitionViewModel.State/recall``:
    ///   Show a passive status label.
    private var footer: some View {
        Group {
            switch vm.state {
            case .idle, .gameOver:
                VStack(spacing: 12) {
                    primaryButton(vm.state == .idle ? "Start" : "Retry") {
                        if vm.state == .gameOver {
                            vm.retrySameGrid()
                        } else {
                            let total = vm.gridSize * vm.gridSize
                            vm.startLevel(totalCells: total)
                        }
                    }

                    secondaryButton("Back") {
                        vm.saveProgressOnExit()
                        currentPage = "Games"
                    }
                }

            case .success:
                VStack(spacing: 12) {
                    primaryButton(vm.gridSize < vm.maxGridSize
                                  ? "Next ( \(vm.gridSize + 1)×\(vm.gridSize + 1) )"
                                  : "Restart (4×4)") {
                        vm.nextGrid()
                    }

                    secondaryButton("Back") {
                        vm.saveProgressOnExit()
                        currentPage = "Games"
                    }
                }

            case .showPattern, .recall:
                Text(vm.state == .showPattern ? "Memorising…" : "Your turn")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
            }
        }
    }

    
    private func primaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
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
    
    private func secondaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.vertical, 10)
                .padding(.horizontal, 14)
                .overlay(Capsule().stroke(.white.opacity(0.8), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

//#Preview {
//    PatternRecognitionView(currentPage: .constant("Games"))
//}
