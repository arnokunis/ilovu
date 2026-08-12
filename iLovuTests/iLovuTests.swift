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

// The Food & Drink cuisine sub-filter. Pure type→bucket mapping, so it's testable
// without Places, Firestore or a deck. The contract that matters for the UI: a
// generic/unknown type maps to NO bucket (nil), which is a normal outcome — those
// venues still show under All / Food & Drink, they just never claim a cuisine pill.
struct PlaceCuisineTests {

    @Test func mapsSpecificRestaurantTypesToBuckets() {
        #expect(PlaceCuration.cuisine(forPrimaryType: "italian_restaurant") == .italian)
        #expect(PlaceCuration.cuisine(forPrimaryType: "pizza_restaurant") == .italian)
        #expect(PlaceCuration.cuisine(forPrimaryType: "sushi_restaurant") == .japanese)
        #expect(PlaceCuration.cuisine(forPrimaryType: "thai_restaurant") == .asian)
        #expect(PlaceCuration.cuisine(forPrimaryType: "greek_restaurant") == .mediterranean)
        #expect(PlaceCuration.cuisine(forPrimaryType: "steak_house") == .grill)
        #expect(PlaceCuration.cuisine(forPrimaryType: "coffee_shop") == .cafe)
        #expect(PlaceCuration.cuisine(forPrimaryType: "vegan_restaurant") == .veggie)
    }

    @Test func genericOrUnknownTypeClaimsNoBucket() {
        // `restaurant` is deliberately unmapped — it says nothing about cuisine.
        #expect(PlaceCuration.cuisine(forPrimaryType: "restaurant") == nil)
        #expect(PlaceCuration.cuisine(forPrimaryType: "some_future_google_type") == nil)
        #expect(PlaceCuration.cuisine(forPrimaryType: "") == nil)
        #expect(PlaceCuration.cuisine(forPrimaryType: nil) == nil)
    }

    @Test func matchesCaseInsensitively() {
        #expect(PlaceCuration.cuisine(forPrimaryType: "Italian_Restaurant") == .italian)
    }

    @Test func displayOrderCoversEveryCuisine() {
        // Pills render from cuisineDisplayOrder, so a case missing from it would be
        // silently unreachable in the UI even when the deck contains it.
        #expect(Set(PlaceCuration.cuisineDisplayOrder) == Set(PlaceCuration.Cuisine.allCases))
        #expect(PlaceCuration.cuisineDisplayOrder.count == PlaceCuration.Cuisine.allCases.count)
    }
}

// normalizeInviteCode — what people ACTUALLY paste into "Have a code?".
// Before 2026-08-12 anything URL-shaped was stripped to garbage
// ("https://ilovu.io/invite/mtv7w" -> "httpsilovuioinvitemtv7w") and could never
// resolve, silently. The invite page's primary action is now "Copy my code", so
// pasted links arrive here more often, not less.
struct InviteCodeNormalizationTests {

    @Test func acceptsATypedCode() {
        #expect(CoupleService.normalizeInviteCode("MTV7W") == "mtv7w")
        #expect(CoupleService.normalizeInviteCode(" mtv7w ") == "mtv7w")
        #expect(CoupleService.normalizeInviteCode("MTV-7W") == "mtv7w")
    }

    @Test func acceptsAPastedUniversalLink() {
        #expect(CoupleService.normalizeInviteCode("https://ilovu.io/invite/mtv7w") == "mtv7w")
        #expect(CoupleService.normalizeInviteCode("https://www.ilovu.io/invite/mtv7w") == "mtv7w")
    }

    @Test func acceptsAPastedCustomSchemeLink() {
        #expect(CoupleService.normalizeInviteCode("ilovu://invite/mtv7w") == "mtv7w")
    }

    /// The mission invite appends the plan (?p=…&w=…), so the query must not
    /// bleed into the token.
    @Test func stripsPlanQueryParams() {
        #expect(CoupleService.normalizeInviteCode(
            "https://ilovu.io/invite/mtv7w?p=Alchemikas&w=2026-08-16&n=Arnoldas") == "mtv7w")
    }

    /// Not a parseable URL, but the shape is unmistakable — someone pasting from
    /// a message that lost its scheme.
    @Test func acceptsASchemelessLink() {
        #expect(CoupleService.normalizeInviteCode("ilovu.io/invite/mtv7w") == "mtv7w")
    }

    /// Crockford look-alike mapping still applies to the extracted token.
    @Test func stillFixesLookAlikeTypos() {
        #expect(CoupleService.normalizeInviteCode("MTVOW") == "mtv0w")
    }
}
