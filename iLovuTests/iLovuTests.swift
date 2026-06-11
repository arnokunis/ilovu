//
//  iLovuTests.swift
//  iLovuTests
//
//  Created by Arnoldas on 20/05/2026.
//

import Testing
import Foundation
@testable import iLovu

struct iLovuTests {

    @Test func example() async throws {
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
    }

}

// Deep-link plumbing for invite links (ilovu://invite/<token>). These exercise
// the exact parse/build path that onOpenURL feeds, without needing Firestore.
struct InviteDeepLinkTests {

    @Test func parsesTokenFromValidLink() {
        let url = URL(string: "ilovu://invite/testcode123")!
        #expect(CoupleService.inviteToken(from: url) == "testcode123")
    }

    @Test func buildAndParseRoundTrip() {
        let token = "abc234xyz"
        let url = CoupleService.inviteURL(token: token)
        #expect(url.absoluteString == "ilovu://invite/abc234xyz")
        #expect(CoupleService.inviteToken(from: url) == token)
    }

    @Test func rejectsWrongScheme() {
        let url = URL(string: "https://invite/testcode123")!
        #expect(CoupleService.inviteToken(from: url) == nil)
    }

    @Test func rejectsWrongHost() {
        let url = URL(string: "ilovu://redeem/testcode123")!
        #expect(CoupleService.inviteToken(from: url) == nil)
    }

    @Test func rejectsMissingToken() {
        let url = URL(string: "ilovu://invite")!
        #expect(CoupleService.inviteToken(from: url) == nil)
    }
}
