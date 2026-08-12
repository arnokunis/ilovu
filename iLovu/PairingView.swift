// PairingView.swift
// The couple-pairing screen. Two ways in:
//   * Create an invite  -> mints a token and offers a share sheet for it.
//   * Redeem a code     -> consumes a partner's invite and forms the couple.
// Presented as a sheet from UsView. All Firestore work goes through
// CoupleService; this view only drives state + presentation.

import SwiftUI
import UIKit
import CoreImage.CIFilterBuiltins
import FirebaseCore

struct PairingView: View {

    @Environment(CoupleService.self) private var couples
    @Environment(AuthState.self) private var authState
    @Environment(\.dismiss) private var dismiss

    // When set (deep link: ilovu://invite/<token>), the screen prefills this
    // code and redeems it automatically on appear. nil for the normal manual flow.
    var autoRedeem: String? = nil

    // What the screen is showing right now. We start in `.loading` while we
    // check whether the user is already in a couple, so we never flash the
    // "invite your partner" UI at someone who's already paired.
    private enum Phase {
        case loading
        case unpaired
        case paired(Couple)
    }

    @State private var phase: Phase = .loading
    @State private var inviteToken: String?      // set once an invite is minted
    @State private var redeemCode: String = ""
    @State private var isWorking = false         // disables buttons mid-request
    @State private var errorMessage: String?
    @State private var didCopy = false           // brief "Copied ✓" feedback on the copy button
    @State private var showPushAsk = false       // warm "know when they join" permission ask
    @State private var didLogReached = false     // one-shot guard for reached_pairing_screen

    var body: some View {
        NavigationStack {
            ZStack {
                Color.blushCream.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        switch phase {
                        case .loading:  loadingState
                        case .unpaired: unpairedState
                        case .paired:   pairedState
                        }

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Color.passRed)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Connect")
            .navigationBarTitleDisplayMode(.inline)
            // Warm, partner-framed permission ask (anti-pressure: "Not now"
            // defers without burning the one-shot iOS prompt — that only fires
            // on "Sounds good", mirroring the first-match ask).
            .alert("Stay in the loop 💕", isPresented: $showPushAsk) {
                Button("Sounds good") { Task { await PushAuthorization.request() } }
                Button("Not now", role: .cancel) { }
            } message: {
                // ONE grant turns on every push type (match / plan / daily-question
                // nudges + all special-date reminders) — there's no per-type toggle,
                // so the copy says "all". Warm + partner-framed, never guilt-based.
                Text("Turn on all of iLovu's reminders in one tap — matches, when your partner plans a date, and special days like your anniversary, engagement and birthdays.")
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .task { await start() }
    }

    // MARK: - States

    private var loadingState: some View {
        ProgressView()
            .controlSize(.large)
            .tint(Color.louvCoral)
            .padding(.top, 80)
    }

    private var pairedState: some View {
        VStack(spacing: 14) {
            Image(systemName: "heart.fill")
                .font(.system(size: 56))
                .foregroundStyle(Color.louvCoral)
                .padding(.top, 48)

            // Name the PARTNER (the member that isn't you) once they've set a
            // name; fall back to the generic line until then.
            Text(couples.partnerDisplayName.map { "Connected with \($0) 💕" } ?? "You're connected 💕")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Color.deepRose)
                .multilineTextAlignment(.center)

            Text("You and your partner are paired. Your story is shared from here on.")
                .font(.system(size: 15))
                .foregroundStyle(.gray)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var unpairedState: some View {
        // --- Create an invite ---
        card {
            Text("Invite your partner")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color.deepRose)

            Text("Create a one-time code and share it with your partner. When they enter it, you'll be connected.")
                .font(.system(size: 14))
                .foregroundStyle(.gray)
                .fixedSize(horizontal: false, vertical: true)

            if let inviteToken {
                // Minted code: shown grouped + uppercased for legibility, with a
                // one-tap copy. The code itself stays the raw lowercase token —
                // copy puts THAT on the clipboard so paste/redeem is clean.
                HStack(spacing: 10) {
                    Text(CoupleService.formatInviteCode(inviteToken))
                        .font(.system(size: 20, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.deepRose)
                        .textSelection(.enabled)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Button {
                        copyCode(inviteToken)
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: didCopy ? "checkmark" : "doc.on.doc")
                            Text(didCopy ? "Copied" : "Copy")
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.louvCoral)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background(Color.white)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 14)
                .frame(maxWidth: .infinity)
                .background(Color.blushCream)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                // Share PLAIN TEXT that leads with the code, link second — so an
                // app that strips ilovu:// links (Messenger) still delivers a
                // usable code. The raw token in the link is unchanged.
                ShareLink(
                    item: CoupleService.inviteShareMessage(token: inviteToken),
                    subject: Text("Join me on iLovu")
                ) {
                    primaryLabel("Share invite", systemImage: "square.and.arrow.up")
                }

                qrSection(token: inviteToken)
            } else {
                Button {
                    Task { await createInvite() }
                } label: {
                    primaryLabel("Create invite code", systemImage: "link")
                }
                .disabled(isWorking)
            }
        }

        Text("or")
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.gray)

        // --- Redeem a code ---
        card {
            Text("Have a code?")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color.deepRose)

            Text("Enter the code your partner shared with you.")
                .font(.system(size: 14))
                .foregroundStyle(.gray)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                TextField("Invite code", text: $redeemCode)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.system(size: 16, design: .monospaced))
                    // Explicit dark text — the background is always the light
                    // blushCream, so the default label color goes invisible
                    // (white) in dark mode. Matches the minted-code Text above.
                    .foregroundStyle(Color.deepRose)
                    .tint(Color.louvCoral)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 14)
                    .frame(maxWidth: .infinity)
                    .background(Color.blushCream)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                // One-tap paste — handles a raw code OR a full ilovu://invite/<token>
                // link (extracts the token), so whatever the partner sent works.
                Button {
                    pasteCode()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "doc.on.clipboard")
                        Text("Paste")
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.louvCoral)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 14)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            Button {
                Task { await redeem() }
            } label: {
                primaryLabel("Connect", systemImage: "heart.circle.fill")
            }
            .disabled(isWorking || redeemCode.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }

    // MARK: - Reusable bits

    // A white rounded card with our standard soft shadow.
    /// Scan-to-pair. The single most common pairing moment for a couples app is
    /// the two people being in the same room — where messaging a link is absurd
    /// friction. iOS's built-in Camera reads this and opens the Universal Link
    /// straight into the app, so NO scanner had to be built on our side: the
    /// partner just points their phone.
    ///
    /// Encodes the plain invite URL (not the share message) because a QR payload
    /// must be a single actionable thing — extra prose would stop the Camera from
    /// offering the link.
    @ViewBuilder
    private func qrSection(token: String) -> some View {
        if let qr = Self.qrImage(from: CoupleService.inviteWebURL(token: token).absoluteString) {
            VStack(spacing: 8) {
                Text("Together right now? Let them scan this")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.gray)
                    .multilineTextAlignment(.center)

                Image(uiImage: qr)
                    .interpolation(.none)          // keep the modules crisp
                    .resizable()
                    .scaledToFit()
                    .frame(width: 168, height: 168)
                    .padding(10)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .accessibilityLabel("QR code to connect")
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 4)
        }
    }

    /// CoreImage QR generation — no third-party dependency for what is one filter.
    /// Medium correction tolerates a little glare/angle on a phone screen without
    /// bloating the module count.
    private static func qrImage(from string: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        // Scale up BEFORE rasterizing: the generator emits roughly one pixel per
        // module, which would render as a blurry smear at display size.
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        guard let cg = CIContext().createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cg)
    }

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12, content: content)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .louvShadow()
    }

    // The coral gradient pill used for every primary action here.
    private func primaryLabel(_ title: String, systemImage: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
            Text(title).font(.system(size: 16, weight: .semibold))
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(LouvGradient.coral)
        .clipShape(Capsule())
        .opacity(isWorking ? 0.6 : 1)
    }

    // MARK: - Actions

    // On appear: load the current couple, then — if we arrived via a deep link
    // and aren't already paired — redeem the linked token automatically.
    private func start() async {
        await loadCouple()
        if case .unpaired = phase, let autoRedeem {
            redeemCode = autoRedeem
            await redeem()
        }
    }

    private func loadCouple() async {
        // Skip in previews / unconfigured environments — touching Firestore or
        // Auth before FirebaseApp.configure() would crash, same guard AuthState uses.
        guard FirebaseApp.app() != nil else { phase = .unpaired; return }
        do {
            if let couple = try await couples.currentCouple() {
                phase = .paired(couple)
            } else {
                phase = .unpaired
                logReachedPairingOnce()
            }
        } catch {
            // Couldn't check — let them act anyway; the rules are the real gate.
            phase = .unpaired
            logReachedPairingOnce()
            errorMessage = error.localizedDescription
        }
    }

    /// Funnel step BETWEEN onboarding_complete and invite_created: an unpaired
    /// user actually reached the invite/redeem UI. Makes the big "installed but
    /// never tried to pair" leak measurable — is the drop before they get here
    /// (never navigate to pairing) or after (here, but create no invite)? Fired
    /// once per presentation, and only in the .unpaired state (an already-paired
    /// user re-opening Connect isn't part of the acquisition funnel).
    private func logReachedPairingOnce() {
        guard !didLogReached else { return }
        didLogReached = true
        AppAnalytics.log("reached_pairing_screen")
    }

    private func createInvite() async {
        isWorking = true
        errorMessage = nil
        do {
            inviteToken = try await couples.createInvite()
            // Warm push ask at the pairing moment (same anti-pressure pattern as
            // the first-match ask in MainTabView): the SYSTEM one-shot prompt
            // only fires on "Sounds good", so "Not now" never burns it. Granting
            // here is what powers the "your partner connected 💕" push.
            if await PushAuthorization.status() == .notDetermined {
                showPushAsk = true
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isWorking = false
    }

    // Copies the RAW token (not the formatted display) so a paste elsewhere is
    // clean, with a brief "Copied ✓" confirmation on the button.
    private func copyCode(_ token: String) {
        UIPasteboard.general.string = token
        withAnimation { didCopy = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation { didCopy = false }
        }
    }

    // Pulls a code from the clipboard. Accepts either a bare code or a full
    // ilovu://invite/<token> link (the share-sheet form), extracting the token.
    private func pasteCode() {
        guard let clip = UIPasteboard.general.string?
            .trimmingCharacters(in: .whitespacesAndNewlines), !clip.isEmpty else { return }
        if let url = URL(string: clip), let token = CoupleService.inviteToken(from: url) {
            redeemCode = token
        } else {
            redeemCode = clip
        }
    }

    private func redeem() async {
        // Normalize formatting/case/look-alikes so a typed or pasted code resolves.
        let code = CoupleService.normalizeInviteCode(redeemCode)
        guard !code.isEmpty else { return }
        isWorking = true
        errorMessage = nil
        do {
            _ = try await couples.redeem(token: code)
            await loadCouple()   // re-fetch so the screen flips to the paired state
            // Ask the REDEEMER for notification permission too. Previously only the
            // invite CREATOR was asked (at invite creation) — so a partner who
            // joined by redeeming never registered for push, had no FCM token on the
            // couple doc, and silently received nothing (and nudges to them reported
            // "didn't send"). Same warm one-shot ask; "Not now" doesn't burn it.
            if await PushAuthorization.status() == .notDetermined {
                showPushAsk = true
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isWorking = false
    }
}

#Preview {
    PairingView()
        .environment(CoupleService())
        .environment(AuthState())
}
