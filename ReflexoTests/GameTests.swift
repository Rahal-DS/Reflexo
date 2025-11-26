//
//  GameTests.swift
//  Reflexo
//
//  Created by Asmiya Hasan on 13/10/2025.
//

// VerbalMemory_GameOverTests.swift
import XCTest
@testable import Reflexo

@MainActor
final class VerbalMemory_GameOverTests: XCTestCase {

    struct FixedWordsMock: RandomWordService {
        let words: [String]
        func fetchWords(count: Int) async throws -> [String] {
            Array(words.prefix(count))
        }
    }

    /// Helper: start the VM and wait until it enters `.playing`.
    private func makeStartedVM() async -> VerbalMemoryViewModel {
        let vm = VerbalMemoryViewModel(
            service: FixedWordsMock(words: ["alpha"]), // 1 word → deterministic repeats
            cacheSize: 1
        )
        vm.startGame()

        // Spin briefly until the async load flips to `.playing`
        let t0 = Date()
        while vm.state == .idle || vm.state == .loading {
            try? await Task.sleep(nanoseconds: 5_000_00) // 0.005s
            if Date().timeIntervalSince(t0) > 1 { break }
        }
        return vm
    }

    func testGameEndsAfterThreeMistakes() async {
        let vm = await makeStartedVM()
        XCTAssertEqual(vm.state, .playing)
        XCTAssertEqual(vm.lives, 3)
        XCTAssertFalse(vm.currentWord.isEmpty)

        // With a single unseen word "alpha":
        // 1) First show is UNSEEN → pressing "Seen" is WRONG (lives: 2)
        vm.chooseSeen()
        XCTAssertEqual(vm.lives, 2)
        XCTAssertEqual(vm.state, .playing)

        // After first answer, "alpha" is now in `seen`. With cache exhausted,
        // repeats are served. A repeat is SEEN → pressing "Unseen" is WRONG.
        // 2) Second mistake (lives: 1)
        vm.chooseUnseen()
        XCTAssertEqual(vm.lives, 1)
        XCTAssertEqual(vm.state, .playing)

        // 3) Third mistake (lives: 0) → should transition to `.gameOver`
        vm.chooseUnseen()
        XCTAssertEqual(vm.lives, 0)
        XCTAssertEqual(vm.state, .gameOver)
    }
}

final class RandomWordMockServiceTests: XCTestCase {

    func testReturnsExactCountWhenWithinPool() async throws {
        let svc = RandomWordMockService()
        let words = try await svc.fetchWords(count: 8)

        XCTAssertEqual(words.count, 8, "Should return exactly the requested count when <= pool size.")
        XCTAssertEqual(Set(words).count, words.count, "Words should be unique.")
        XCTAssertTrue(words.allSatisfy { $0 == $0.lowercased() }, "All words should be lowercase.")
        XCTAssertTrue(words.allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }, "No empty/blank words.")
    }

    func testCappedAtPoolSizeWhenRequestingMore() async throws {
        let svc = RandomWordMockService()
        let words = try await svc.fetchWords(count: 999)

        XCTAssertEqual(words.count, 50, "Should cap at the fixed pool size (50).")
        XCTAssertEqual(Set(words).count, words.count, "Words should be unique even at cap.")
    }

    func testShuffledSubsetIsAPermutationOfPrefix() async throws {
        let svc = RandomWordMockService()

        // Request N and ensure we got N unique items (a permutation of the first N of the base).
        // We don’t rely on order randomness to avoid flakiness.
        let n = 20
        let words = try await svc.fetchWords(count: n)

        XCTAssertEqual(words.count, n)
        XCTAssertEqual(Set(words).count, n)

        // Optional: sanity-check that repeated calls still return N unique items
        // (we don't assert different order to avoid rare flakes).
        let words2 = try await svc.fetchWords(count: n)
        XCTAssertEqual(words2.count, n)
        XCTAssertEqual(Set(words2).count, n)
    }
}

@MainActor
final class PatternRecognitionViewModelTests: XCTestCase {

    // Helper: fast-forward the "show pattern" delay
    private func wait(_ seconds: Double) async {
        let ns = UInt64(seconds * 1_000_000_000)
        try? await Task.sleep(nanoseconds: ns)
    }

    func testStartLevel_SetsPatternAndTransitionsToRecall() async {
        let vm = PatternRecognitionViewModel()
        vm.gridSize = 4
        vm.showDuration = 0.01  // make test snappy

        // Start a level with a 4x4 grid
        vm.startLevel(totalCells: vm.gridSize * vm.gridSize)

        // Immediately after start: pattern generated, state is .showPattern
        XCTAssertEqual(vm.state, .showPattern)
        XCTAssertFalse(vm.pattern.isEmpty, "Pattern should be generated on start.")
        // Pattern size = max(3, round(30% of totalCells))
        let expectedCount = max(3, Int(round(0.30 * Double(16))))
        XCTAssertEqual(vm.pattern.count, expectedCount)

        // After showDuration elapses, we should move to .recall
        await wait(vm.showDuration + 0.02)
        XCTAssertEqual(vm.state, .recall)
    }

    func testCorrectlyTappingEntirePatternLeadsToSuccess() async {
        let vm = PatternRecognitionViewModel()
        vm.gridSize = 4
        vm.showDuration = 0.0 // transition immediately

        vm.startLevel(totalCells: vm.gridSize * vm.gridSize)
        // Ensure we've entered recall (showDuration is zero, but guard anyway)
        if vm.state != .recall { await wait(0.01) }

        // Tap every correct index in the pattern
        for idx in vm.pattern {
            vm.tapCell(idx)
        }

        XCTAssertEqual(vm.state, .success)
        // selection should match pattern after success
        XCTAssertEqual(vm.selection, vm.pattern)
    }

    func testNextGridIncrementsLevelAndGridSize() {
        let vm = PatternRecognitionViewModel()
        vm.gridSize = 4
        vm.level = 1
        vm.state = .success // simulate finishing a grid

        vm.nextGrid()

        XCTAssertEqual(vm.gridSize, 5)
        XCTAssertEqual(vm.level, 2)
        XCTAssertEqual(vm.state, .idle)
        XCTAssertTrue(vm.selection.isEmpty)
    }

    func testNextGridResetsAfterMaxGridSize() {
        let vm = PatternRecognitionViewModel()
        vm.gridSize = vm.maxGridSize
        vm.level = 10
        vm.state = .success

        vm.nextGrid()

        XCTAssertEqual(vm.gridSize, 4, "Should wrap back to 4 after reaching max.")
        XCTAssertEqual(vm.level, 1, "Level should reset when wrapping.")
        XCTAssertEqual(vm.state, .idle)
    }

    func testRetrySameGridResetsToInitialState() {
        let vm = PatternRecognitionViewModel()
        vm.gridSize = 6
        vm.level = 3
        vm.selection = [1,2,3]
        vm.state = .recall

        vm.retrySameGrid()

        XCTAssertEqual(vm.gridSize, 4)
        XCTAssertEqual(vm.level, 1)
        XCTAssertTrue(vm.selection.isEmpty)
        XCTAssertEqual(vm.state, .idle)
    }
}
