//
//  ProfileTests.swift
//  Reflexo
//
//  Created by Asmiya Hasan on 13/10/2025.
//

// HandleValidatorTests.swift
import XCTest
@testable import Reflexo

final class HandleValidatorTests: XCTestCase {

    func testInvalidDisplayNames_ThrowInvalidName() {
        let invalids = ["Foo Bar", "Äsmiya", "🤖", "", "ABC "]
        for name in invalids {
            XCTAssertThrowsError(try HandleValidator.normalizeAndValidate(name), "Expected invalid: \(name)") { error in
                XCTAssertEqual(error as? HandleError, .invalidName)
            }
        }
    }

    func testValidMixedCase_IsLowercasedKey() throws {
        let key = try HandleValidator.normalizeAndValidate("Asmiya_01")
        XCTAssertEqual(key, "asmiya_01")
    }

    func testProfileBuild_StoresLowercasedHandleKey() throws {
        struct AppUser {
            let uid: String
            let displayName: String
            let handleKey: String
        }
        let display = "Asmiya_01"
        let key = try HandleValidator.normalizeAndValidate(display)
        let user = AppUser(uid: "u1", displayName: display, handleKey: key)
        XCTAssertEqual(user.displayName, "Asmiya_01")
        XCTAssertEqual(user.handleKey, "asmiya_01")
    }
}
