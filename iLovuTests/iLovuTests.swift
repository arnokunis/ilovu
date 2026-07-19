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

    // Universal Links (https://ilovu.io/invite/<token>) — same parser, same
    // onOpenURL delivery. The scheme link keeps working alongside.

    @Test func parsesTokenFromUniversalLink() {
        let url = URL(string: "https://ilovu.io/invite/k2mn8")!
        #expect(CoupleService.inviteToken(from: url) == "k2mn8")
    }

    @Test func parsesTokenFromWWWUniversalLink() {
        let url = URL(string: "https://www.ilovu.io/invite/k2mn8")!
        #expect(CoupleService.inviteToken(from: url) == "k2mn8")
    }

    @Test func webBuildAndParseRoundTrip() {
        let token = "abc23"
        let url = CoupleService.inviteWebURL(token: token)
        #expect(url.absoluteString == "https://ilovu.io/invite/abc23")
        #expect(CoupleService.inviteToken(from: url) == token)
    }

    @Test func rejectsUniversalLinkOnWrongDomain() {
        let url = URL(string: "https://evil.io/invite/k2mn8")!
        #expect(CoupleService.inviteToken(from: url) == nil)
    }

    @Test func rejectsUniversalLinkWithWrongPath() {
        // Not an invite path — e.g. the privacy page must not parse as a token.
        let url = URL(string: "https://ilovu.io/privacy")!
        #expect(CoupleService.inviteToken(from: url) == nil)
    }

    @Test func rejectsUniversalLinkWithMissingToken() {
        let url = URL(string: "https://ilovu.io/invite")!
        #expect(CoupleService.inviteToken(from: url) == nil)
    }

    @Test func rejectsUniversalLinkWithExtraPathParts() {
        let url = URL(string: "https://ilovu.io/invite/k2mn8/extra")!
        #expect(CoupleService.inviteToken(from: url) == nil)
    }
}

// Partner display-name resolution — the pure logic behind "each user sees the
// OTHER's name, never their own." This is the exact regression that was reported
// (A seeing A's own name), so it's worth locking down without needing Firestore.
struct CouplePartnerNameTests {

    private func couple(_ displayNames: [String: String]) -> Couple {
        Couple(id: "couple1", members: ["uidA", "uidB"], displayNames: displayNames, createdAt: nil)
    }

    @Test func partnerIsTheOtherMember() {
        let c = couple([:])
        #expect(c.partner(of: "uidA") == "uidB")
        #expect(c.partner(of: "uidB") == "uidA")
    }

    @Test func eachSideSeesTheOthersName_notTheirOwn() {
        let c = couple(["uidA": "Alex", "uidB": "Bea"])
        // From A's point of view the partner is Bea — NOT Alex.
        #expect(c.partnerName(currentUid: "uidA") == "Bea")
        // From B's point of view the partner is Alex.
        #expect(c.partnerName(currentUid: "uidB") == "Alex")
    }

    @Test func nilWhenOnlySelfHasSetAName() {
        // Only A has set a name: A sees no partner name yet, B sees Alex.
        let c = couple(["uidA": "Alex"])
        #expect(c.partnerName(currentUid: "uidA") == nil)
        #expect(c.partnerName(currentUid: "uidB") == "Alex")
    }

    @Test func nilWhenPartnerNameIsBlank() {
        // A blank/whitespace entry is treated as unset, not shown.
        let c = couple(["uidB": "   "])
        #expect(c.partnerName(currentUid: "uidA") == nil)
    }

    @Test func nilWhenNoDisplayNamesAtAll() {
        let c = Couple(id: "c", members: ["uidA", "uidB"], createdAt: nil)
        #expect(c.partnerName(currentUid: "uidA") == nil)
    }
}
