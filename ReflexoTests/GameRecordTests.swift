//
//  GameRecordTests.swift
//  Reflexo
//
//  Created by Asmiya Hasan on 12/10/2025.
//

import XCTest
import SwiftData
@testable import Reflexo

@MainActor
final class GameRecordTests: XCTestCase {
    var container: ModelContainer!
    var ctx: ModelContext!

    override func setUp() {
        super.setUp()
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try! ModelContainer(for: GameRecord.self, configurations: config)
        ctx = container.mainContext
    }

    func testInsertAndFetch() throws {
        // Insert
        let rec = GameRecord(uid: "u1", displayName: "Player",
                             game: "ReactionTime", score: 250, rankScore: 250, accuracy: 1.0, attemptedAt: .now)
        ctx.insert(rec)
        try ctx.save()

        // Fetch
        let fd = FetchDescriptor<GameRecord>(
            predicate: #Predicate { $0.game == "ReactionTime" }
        )
        let fetched = try ctx.fetch(fd)

        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.score, 250)
        XCTAssertEqual(fetched.first?.accuracy, 1.0)
        XCTAssertEqual(fetched.first?.displayName, "Player")
    }
}
