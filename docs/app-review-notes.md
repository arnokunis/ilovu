# App Review notes

Paste into **App Store Connect → App Information / Version → App Review Information → Notes**.

Kept in the repo so the reviewer-access instructions stay versioned with the build that relies on them (the hidden demo-login gesture in `SignInView`, the demo couple's seeded data, and the non-premium paywall path).

## Pre-submit checklist
- [ ] `appreview@ilovu.app` exists in Firebase Auth with the demo password (kept OUT of this file — set it in Firebase Auth and paste it into the App Store Connect notes; the two must match). Email/Password provider enabled.
- [ ] The demo couple is **non-premium** (`couples/{id}.isPremium` not `true`) so the paywall appears when the reviewer taps a Mission on Home.
- [ ] The demo couple is seeded (2 matches, a completed mission with a Vault photo, an answered Daily Question) and its `coupleId` claim is set (so Vault photos load — hardening #3).
- [ ] The subscription products are attached to this version and sandbox-purchasable (confirmed: purchase completes and unlocks Premium).
- [ ] Verify the hidden login gesture on the exact build being uploaded.

## Notes text

```
SIGN-IN FOR REVIEW
iLovu uses Sign in with Apple, which the review team can't complete, so we've
provided a demo account that logs in with email and password.

How to reveal the login: On the first screen ("Sign in to save your sparks…"),
press and hold the large "iLovu" title for about 2 seconds. An email and
password field appears below the Apple button.

Demo credentials:
  Email:    appreview@ilovu.app
  Password: «fill in when pasting into App Store Connect — kept out of git»

WHAT YOU'LL SEE
This account is already paired with a partner, so it opens directly into the
full two-partner experience: sample matched date ideas, a completed date with a
photo in the shared Memory Vault, and an answered Daily Question. You can also
browse Home, the swipe Cards, "Near You" (curated local venues), and the "Us"
tab.

THE CORE LOOP
Both partners swipe date ideas → a mutual match becomes a Mission → completing
it captures a Proof Photo into the shared Memory Vault.

SUBSCRIPTION / IN-APP PURCHASE (for IAP review)
iLovu offers an auto-renewing subscription (annual or monthly). The demo account
is FREE (not subscribed), so you can review the purchase flow directly:
  • From the Home tab, tap any Mission card — the subscription paywall appears,
    showing the plans and prices.
  • You can complete the purchase there (it completes in the StoreKit sandbox
    for review and unlocks Premium), or tap the "X" in the top corner to close it.
  • The app stays fully usable without subscribing: swiping, matching, and —
    right after a match — tapping "Plan This Date" opens the full date-planning
    (Mission) flow; "Near You" and the Memory Vault are also open. So no feature
    is a dead end whether or not you subscribe.

CONTENT & PRIVACY (no public user-generated content)
All user content — proof photos, memories, daily-question answers — is PRIVATE
to the two paired partners. It is visible only to the couple, enforced
server-side: Cloud Storage and Firestore access is scoped to the couple via a
per-account couple-membership claim, so no other user can read another couple's
photos or data. There is NO public feed, no discovery, no profiles of strangers,
and no way for users to contact or see anyone outside their own partner. As such
there is no public UGC to moderate or report.
```
