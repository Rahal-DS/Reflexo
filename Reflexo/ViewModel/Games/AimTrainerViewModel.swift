//
//  AimTrainerViewModel.swift
//  Reflexo
//
//  Created by Rahal De Silva on 09/10/2025.
//

import SwiftUI
import Combine
import SwiftData
import WidgetKit

/// View model for the **Aim Trainer** mini-game.
///
/// `AimTrainerViewModel` manages target generation/placement, game timing,
/// hit/miss accounting, and end-of-round persistence (Firestore + SwiftData).
/// It also exposes a simple “combo” mode where the user can drag to hit
/// multiple targets quickly.
/// ### Flow
/// - ``startGame(in:count:)`` → creates non-overlapping targets and starts timer
/// - ``hitTarget(id:)`` / ``registerMissTap()`` → update counters + UI
/// - All targets cleared → ``finish()`` → saves score, reloads widget timelines
///
/// ### Persistence
/// - **Remote**: ``FirebaseManager/saveHighScore(game:score:rankScore:accuracy:)``
/// - **Local**: ``GameRecord/saveLocal(_context:uid:displayName:game:score:rankScore:accuracy:)``
///
@MainActor
final class AimTrainerViewModel: ObservableObject {
    
    struct Target: Identifiable, Equatable {
        let id = UUID()
        var position: CGPoint
        var hit: Bool = false
        var scale: CGFloat = 1.0
    }
    
    private let session = UserSessionManager.shared
    private var modelContext: ModelContext?
    
    @Published var targets: [Target] = []
    @Published var isRunning = false
    @Published var gameOver = false
    @Published var elapsed: TimeInterval = 0
    @Published var totalTaps: Int = 0
    @Published var hits: Int = 0
    
    
    @Published var comboActive = false;

    var targetCount: Int = 16
    var targetRadius: CGFloat = 25
    var minSeparation: CGFloat = 80
    
    private var startTime: CFAbsoluteTime?
    private var displayLink: CADisplayLink?
    
    private let fb = FirebaseManager.shared
    
    var remaining: Int { targets.filter { !$0.hit }.count }

    var finalTimeMs: Int {
        Int((elapsed * 1000).rounded())
    }
    
    func attach(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // MARK: - Game Control

   /// Starts a new round by generating non-overlapping targets inside `bounds`
   /// and starting the display-link timer.
   ///
   /// - Parameters:
   ///   - bounds: The playable area size (usually the view’s size in points).
   ///   - count: Optional override for number of targets; defaults to ``targetCount``.
    func startGame(in bounds: CGSize, count: Int? = nil) {
        reset()
        targetCount = count ?? targetCount
        targets = generateNonOverlappingTargets(count: targetCount,
                                                in: bounds,
                                                radius: targetRadius,
                                                minSep: minSeparation)
        isRunning = true
        gameOver = false
        startTimer()
    }
    
    /// Resets in-memory state and stops the timer.
    func reset() {
        stopTimer()
        targets.removeAll()
        isRunning = false
        gameOver = false
        elapsed = 0
        startTime = nil
    }
    
    
    /// Registers a tap that did **not** hit a target.
    ///
    /// No-ops when the round isn’t running.
    func registerMissTap() {
        guard isRunning else { return }
        totalTaps += 1
    }
    

    /// Marks a specific target as hit, animates it out, and removes it.
    ///
    /// When all targets are cleared, calls ``finish()``.
    ///
    /// - Parameter id: The identifier of the target to mark as hit.
    func hitTarget(id: UUID) {
        guard isRunning else { return }
        guard let idx = targets.firstIndex(where: { $0.id == id }) else { return }
        guard !targets[idx].hit else { return }
        
        totalTaps += 1
        hits += 1
        
        withAnimation(.easeOut(duration: 0.25))
        {
            targets[idx].hit = true
            targets[idx].scale = 0.0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25)
        {
            self.targets.removeAll {$0.id == id}
            if self.remaining == 0 {self.finish()}
        }
    }
    
    // MARK: - End of Round

    /// Stops timing, flips flags, and persists the result.
    ///
    /// - Remote: Saves to Firestore via ``FirebaseManager`` then reloads widgets.
    /// - Local: Records a `GameRecord` with score, rank score, and accuracy.
    private func finish() {
        stopTimer()
        isRunning = false
        gameOver = true
        
        let accuracyVal = 1
        let rankScore = Int(finalTimeMs)
        let _game = "AimTrainer"
        
        Task
        {
            do
            {
                try await fb.saveHighScore(
                    game: _game,
                    score: finalTimeMs,
                    rankScore: rankScore,
                    accuracy: accuracyVal
                )
                
                WidgetCenter.shared.reloadAllTimelines()
            }
            
            // Save locally regardless of remote outcome.
            GameRecord.saveLocal(
                _context: modelContext,
                uid: session.uid,
                displayName: session.displayName,
                game: _game,
                score: finalTimeMs,
                rankScore: rankScore,
                accuracy: Float(accuracyVal)
            )
        }
        
    }
    // MARK: - Timer

    /// Begins a display-link timer and anchors a start time.
    private func startTimer() {
        startTime = CFAbsoluteTimeGetCurrent()
        displayLink = CADisplayLink(target: self, selector: #selector(tick))
        displayLink?.add(to: .main, forMode: .common)
    }
    
    /// Invalidates the display-link.
    private func stopTimer() {
        displayLink?.invalidate()
        displayLink = nil
    }
    
    /// Updates ``elapsed`` from the anchored start time.
    @objc private func tick() {
        guard let t0 = startTime else { return }
        elapsed = CFAbsoluteTimeGetCurrent() - t0
    }
    
    // MARK: - Target Layout

      /// Generates `count` target centers within `size`, attempting to keep
      /// them non-overlapping with at least `minSep` spacing (or `radius*2+4`,
      /// whichever is larger).
      ///
      /// The method performs up to `attemptsPerTarget` random placements per
      /// target; if all fail, it falls back to positioning relative to an
      /// already-placed point.
      ///
      /// - Parameters:
      ///   - count: Number of targets to generate.
      ///   - size: Playable area (points).
      ///   - radius: Target radius used for margins and hit testing.
      ///   - minSep: Minimum center-to-center separation.
      /// - Returns: An array of ``Target`` ready to display.
    private func generateNonOverlappingTargets(
        count: Int,
        in size: CGSize,
        radius: CGFloat,
        minSep: CGFloat
    ) -> [Target] {
        var placed: [CGPoint] = []
        let margin = radius + 8
        let minX = margin
        let maxX = max(margin, size.width - margin)
        let minY = margin
        let maxY = max(margin, size.height - margin)
        
        let attemptsPerTarget = 200
        
        for _ in 0..<count {
            var pos: CGPoint?
            for _ in 0..<attemptsPerTarget {
                let x = CGFloat.random(in: minX...maxX)
                let y = CGFloat.random(in: minY...maxY)
                let p = CGPoint(x: x, y: y)
                if placed.allSatisfy({ hypot($0.x - p.x, $0.y - p.y) >= max(minSep, radius * 2 + 4) }) {
                    pos = p
                    break
                }
            }
            if pos == nil, let fallback = placed.randomElement() {
                pos = CGPoint(x: min(maxX, max(minX, fallback.x + minSep)),
                              y: min(maxY, max(minY, fallback.y + minSep)))
            }
            placed.append(pos ?? CGPoint(x: (minX + maxX)/2, y: (minY + maxY)/2))
        }
        
        return placed.map { Target(position: $0) }
    }
    
    
    // MARK: - Combo Mode

    /// Activates combo mode, enabling drag-to-hit behavior.
    func startCombo() {
        guard isRunning else { return }
        comboActive = true
    }

    /// In combo mode, marks any target within ``targetRadius`` of `point` as hit.
    ///
    /// - Parameter point: The current drag location in the same coordinate space
    ///                    used to render targets.
    func dragHit(at point: CGPoint) {
        guard comboActive else { return }
        for target in targets where !target.hit {
            let dx = target.position.x - point.x
            let dy = target.position.y - point.y
            let distance = sqrt(dx*dx + dy*dy)
            if distance <= targetRadius { hitTarget(id: target.id) }
        }
    }
    
    /// Deactivates combo mode.
    func endCombo() {
        comboActive = false
    }

}


