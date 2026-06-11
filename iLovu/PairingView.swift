// PairingView.swift
// The couple-pairing screen. Two ways in:
//   * Create an invite  -> mints a token and offers a share sheet for it.
//   * Redeem a code     -> consumes a partner's invite and forms the couple.
// Presented as a sheet from UsView. All Firestore work goes through
// CoupleService; this view only drives state + presentation.

import SwiftUI
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

            Text("You're connected 💕")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Color.deepRose)

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
                // Show the minted code + a share sheet for it.
                Text(inviteToken)
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.deepRose)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.blushCream)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                ShareLink(
                    item: CoupleService.inviteURL(token: inviteToken),
                    subject: Text("Join me on iLovu"),
                    message: Text("Be my partner on iLovu 💕 Tap to connect.")
                ) {
                    primaryLabel("Share invite", systemImage: "square.and.arrow.up")
                }
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

            TextField("Invite code", text: $redeemCode)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.system(size: 16, design: .monospaced))
                .padding(.vertical, 12)
                .padding(.horizontal, 14)
                .background(Color.blushCream)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

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
            }
        } catch {
            // Couldn't check — let them act anyway; the rules are the real gate.
            phase = .unpaired
            errorMessage = error.localizedDescription
        }
    }

    private func createInvite() async {
        isWorking = true
        errorMessage = nil
        do {
            inviteToken = try await couples.createInvite()
        } catch {
            errorMessage = error.localizedDescription
        }
        isWorking = false
    }

    private func redeem() async {
        let code = redeemCode.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !code.isEmpty else { return }
        isWorking = true
        errorMessage = nil
        do {
            _ = try await couples.redeem(token: code)
            await loadCouple()   // re-fetch so the screen flips to the paired state
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
