// PaywallView.swift
// The soft subscription wall. By design it appears in the warm afterglow of a
// shared moment (a match, a completed mission), so the whole screen leans
// warm and unhurried — never guilt-trippy, never urgent. It's dismissible, and
// the annual plan is pre-selected because one plan covers both partners.
//
// This is the SCREEN ONLY. Real localized prices are FED IN from RevenueCat via
// the optional price-text inputs (HomeView supplies them from SubscriptionService);
// when absent the static copy is the graceful fallback so the wall never looks
// broken. The CTA / Restore call async closures that return a PurchaseOutcome, and
// this view owns just the in-flight + error UI around them — the RevenueCat calls
// and the couple-doc mirror live in SubscriptionService / CoupleService.
//
// Everything visual is pulled from DesignSystem.swift (blushCream, deepRose,
// louvCoral, LouvGradient.coral, LouvAnimation.spring, .louvShadow) plus the
// card recipe used by SwipeView / MatchView, so the wall feels native, not
// bolted on.

import SwiftUI

struct PaywallView: View {

    // MARK: - Configuration

    /// When true the first-500 founding offer is live: the annual plan swaps to
    /// the $39.99/yr founding price and its badge becomes the founding line.
    /// Stubbed for now — real eligibility comes from the backend later.
    var isFoundingEligible: Bool = false

    // Real localized prices from RevenueCat packages, fed by the caller. nil →
    // the static fallback copy in annualInfo/monthlyInfo is used, so the screen
    // renders fully (and previews) without RevenueCat.
    var annualPriceText:    String? = nil   // e.g. "$49.99/yr"
    var annualPerMonthText: String? = nil   // e.g. "just $4.17/mo"
    var monthlyPriceText:   String? = nil   // e.g. "$6.99/mo"

    /// Purchases the plan the user has selected. Returns the outcome so this view
    /// can dismiss on success, ignore a cancel, or surface a friendly error.
    var onPurchase: (Plan) async -> PurchaseOutcome = { _ in .cancelled }

    // The quiet footer actions. Restore is async (returns an outcome); terms /
    // privacy stay simple no-op-able callbacks. Defaults keep previews drop-in.
    var onRestore: () async -> PurchaseOutcome = { .cancelled }
    var onTerms:   () -> Void = {}
    var onPrivacy: () -> Void = {}

    // MARK: - State

    /// The two plans the wall offers. Annual is the hero and is pre-selected.
    enum Plan: Hashable { case annual, monthly }

    @State private var selectedPlan: Plan = .annual
    @State private var appeared = false           // drives the one-shot entrance

    // Purchase / restore in-flight + the last friendly error, if any. Owned here
    // so the CTA can show a spinner and the wall can surface a gentle message
    // without ever crashing on a failed/cancelled purchase.
    @State private var isPurchasing = false
    @State private var isRestoring = false
    @State private var purchaseError: String?

    // Dismiss works when presented as a sheet / fullScreenCover (the intended
    // use). The close button is the soft "wall" escape hatch.
    @Environment(\.dismiss) private var dismiss

    // Honor the system "Reduce Motion" setting — we skip the slide-in transform
    // (a gentle opacity fade is still fine) when it's on.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Dynamic Type
    // The app styles text with fixed `.system(size:)` values; routing those base
    // sizes through @ScaledMetric keeps the exact look but lets them scale with
    // the user's text-size setting. The ScrollView below absorbs the growth.
    @ScaledMetric(relativeTo: .largeTitle)  private var heroSize: CGFloat = 32
    @ScaledMetric(relativeTo: .body)        private var bodySize: CGFloat = 16
    @ScaledMetric(relativeTo: .title3)      private var priceSize: CGFloat = 20
    @ScaledMetric(relativeTo: .headline)    private var titleSize: CGFloat = 17
    @ScaledMetric(relativeTo: .subheadline) private var smallSize: CGFloat = 14
    @ScaledMetric(relativeTo: .headline)    private var ctaSize: CGFloat = 18
    @ScaledMetric(relativeTo: .footnote)    private var fineSize: CGFloat = 13

    // MARK: - Stubbed plan data
    // A single shape so the card UI doesn't care which plan it's rendering, and
    // so swapping these for RevenueCat StoreProducts later is a localized change.

    private struct PlanInfo {
        let plan: Plan
        let title: String
        let price: String       // headline price, e.g. "$49.99/yr"
        let perMonth: String?   // softer per-month framing, e.g. "just $4.17/mo"
        let badge: String?      // floats on the card; annual-only
        let terms: String       // fine print shown under the CTA for this plan
    }

    private var annualInfo: PlanInfo {
        if isFoundingEligible {
            // Founding tier: cheaper, and the badge says why it's special rather
            // than leaning on a discount number.
            PlanInfo(
                plan: .annual,
                title: "Annual",
                price: "$39.99/yr",
                perMonth: "just $3.33/mo",
                badge: "Founding member — first 500 only",
                terms: "$39.99/year, auto-renews. Cancel anytime. One plan covers both partners."
            )
        } else {
            // Real RevenueCat price when fed; static copy as the offline fallback.
            PlanInfo(
                plan: .annual,
                title: "Annual",
                price: annualPriceText ?? "$49.99/yr",
                perMonth: annualPerMonthText ?? "just $4.17/mo",
                badge: "Best value — save 40%",
                terms: "Auto-renews yearly. Cancel anytime. One plan covers both partners."
            )
        }
    }

    private var monthlyInfo: PlanInfo {
        PlanInfo(
            plan: .monthly,
            title: "Monthly",
            price: monthlyPriceText ?? "$6.99/mo",
            perMonth: nil,
            badge: nil,
            terms: "Auto-renews monthly. Cancel anytime. One plan covers both partners."
        )
    }

    /// Fine print follows whatever the user currently has selected.
    private var selectedTerms: String {
        (selectedPlan == .annual ? annualInfo : monthlyInfo).terms
    }

    // The three things subscribing unlocks. Tight by design — a thesis, not a
    // feature dump. (SF Symbol, label).
    private let unlocks: [(icon: String, text: String)] = [
        ("infinity",     "Unlimited missions & matches"),
        ("heart.fill",   "Your shared Memory Vault, forever"),
        ("apps.iphone",  "Home-screen widgets: next date, days together, latest memory")
    ]

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Warm cream — never pure white, per the design system.
            Color.blushCream.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 28) {
                    hero
                    unlocksList
                    plans
                    callToAction
                }
                .padding(.horizontal, 24)
                .padding(.top, 64)   // clears the pinned close button
                .padding(.bottom, 32)
                // One-shot entrance: fade in, and drift up unless Reduce Motion.
                .opacity(appeared ? 1 : 0)
                .offset(y: (appeared || reduceMotion) ? 0 : 16)
            }

            closeButton
                .padding(.top, 12)
                .padding(.trailing, 16)
        }
        .onAppear {
            guard !appeared else { return }
            if reduceMotion {
                appeared = true
            } else {
                withAnimation(LouvAnimation.spring.delay(0.05)) { appeared = true }
            }
        }
    }

    // MARK: - Close

    private var closeButton: some View {
        Button { dismiss() } label: {
            Image(systemName: "xmark")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.gray)
                .frame(width: 34, height: 34)
                .background(Color.white)
                .clipShape(Circle())
                .louvShadow()
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Close")
    }

    // MARK: - Hero

    private var hero: some View {
        VStack(spacing: 14) {
            // Small warm motif — purely decorative, hidden from VoiceOver.
            Text("💕")
                .font(.system(size: 44))
                .accessibilityHidden(true)

            Text("Keep building your story together.")
                .font(.system(size: heroSize, weight: .bold))
                .foregroundStyle(Color.deepRose)
                .multilineTextAlignment(.center)

            Text("One subscription unlocks everything — for both of you.")
                .font(.system(size: bodySize))
                .foregroundStyle(.gray)
                .multilineTextAlignment(.center)
        }
        // Hero + subhead read as one statement to VoiceOver.
        .accessibilityElement(children: .combine)
    }

    // MARK: - Unlocks

    private var unlocksList: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(unlocks, id: \.text) { unlock in
                HStack(spacing: 14) {
                    Image(systemName: unlock.icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.louvCoral)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(Color.louvCoral.opacity(0.12)))
                        .accessibilityHidden(true)

                    Text(unlock.text)
                        .font(.system(size: bodySize, weight: .medium))
                        .foregroundStyle(Color.deepRose)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 0)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Plans

    private var plans: some View {
        // Both plans are shown upfront — no product is hidden behind a tap.
        // Annual stays pre-selected/highlighted (the plan we push); Monthly sits
        // directly below it as a fully selectable option.
        VStack(spacing: 14) {
            planCard(annualInfo)
            planCard(monthlyInfo)
        }
    }

    /// One selectable plan card. Selection is local state; tapping selects.
    private func planCard(_ info: PlanInfo) -> some View {
        let isSelected = selectedPlan == info.plan

        return Button {
            withAnimation(reduceMotion ? nil : LouvAnimation.spring) {
                selectedPlan = info.plan
            }
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                if let badge = info.badge {
                    Text(badge)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(LouvGradient.coral)
                        .clipShape(Capsule())
                        .accessibilityHidden(true)   // folded into the card's label
                }

                HStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(info.title)
                            .font(.system(size: titleSize, weight: .semibold))
                            .foregroundStyle(Color.deepRose)

                        Text(info.price)
                            .font(.system(size: priceSize, weight: .bold))
                            .foregroundStyle(Color.deepRose)

                        if let perMonth = info.perMonth {
                            Text(perMonth)
                                .font(.system(size: smallSize))
                                .foregroundStyle(.gray)
                        }
                    }

                    Spacer(minLength: 0)

                    selectionIndicator(isSelected: isSelected)
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                // Selected → coral 2pt; otherwise the faint deepRose hairline
                // SwipeView's cards use. Same card language across the app.
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(isSelected ? Color.louvCoral : Color.deepRose.opacity(0.12),
                            lineWidth: isSelected ? 2 : 1)
            )
            .louvShadow()
        }
        .buttonStyle(.plain)
        // One spoken element per card, marked selected so VoiceOver users hear
        // which plan is active.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel(for: info))
        .accessibilityAddTraits(.isButton)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private func selectionIndicator(isSelected: Bool) -> some View {
        ZStack {
            Circle()
                .strokeBorder(isSelected ? Color.louvCoral : Color.gray.opacity(0.4),
                              lineWidth: 2)
                .frame(width: 26, height: 26)
            if isSelected {
                Circle().fill(Color.louvCoral).frame(width: 26, height: 26)
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
    }

    private func accessibilityLabel(for info: PlanInfo) -> String {
        var parts = [info.title, info.price]
        if let perMonth = info.perMonth { parts.append(perMonth) }
        if let badge = info.badge { parts.append(badge) }
        return parts.joined(separator: ", ")
    }

    // MARK: - CTA + fine print

    private var callToAction: some View {
        VStack(spacing: 12) {
            Button {
                Task { await runPurchase() }
            } label: {
                Group {
                    if isPurchasing {
                        ProgressView().tint(.white)
                    } else {
                        Text("Start together")
                            .font(.system(size: ctaSize, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(LouvGradient.coral)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(isPurchasing || isRestoring)
            .louvShadow()
            .accessibilityLabel("Start together")

            // Required legal-ish clarity, kept legible (not 8pt gray mouse type).
            Text(selectedTerms)
                .font(.system(size: fineSize))
                .foregroundStyle(.gray)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            // Gentle, non-crashing failure surface (cancellations show nothing).
            if let purchaseError {
                Text(purchaseError)
                    .font(.system(size: fineSize, weight: .medium))
                    .foregroundStyle(Color.deepRose)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity)
            }

            footer
                .padding(.top, 4)
        }
    }

    // MARK: - Purchase / restore actions

    @MainActor
    private func runPurchase() async {
        guard !isPurchasing, !isRestoring else { return }
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) { purchaseError = nil }
        isPurchasing = true
        let outcome = await onPurchase(selectedPlan)
        isPurchasing = false
        handle(outcome)
    }

    @MainActor
    private func runRestore() async {
        guard !isPurchasing, !isRestoring else { return }
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) { purchaseError = nil }
        isRestoring = true
        let outcome = await onRestore()
        isRestoring = false
        handle(outcome)
    }

    @MainActor
    private func handle(_ outcome: PurchaseOutcome) {
        switch outcome {
        case .success:
            dismiss()                       // premium active — the gate stops presenting
        case .cancelled:
            break                           // user backed out — say nothing
        case .failed(let message):
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) {
                purchaseError = message
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 10) {
            footerButton("Restore purchase") { Task { await runRestore() } }
            footerDot
            footerButton("Terms", action: onTerms)
            footerDot
            footerButton("Privacy", action: onPrivacy)
        }
        .font(.system(size: fineSize))
        .foregroundStyle(.gray)
    }

    private var footerDot: some View {
        Text("·").foregroundStyle(.gray.opacity(0.6)).accessibilityHidden(true)
    }

    private func footerButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .buttonStyle(.plain)
            .foregroundStyle(.gray)
    }
}

// MARK: - Previews
// Stubbed plans, so the screen renders fully in the canvas with no RevenueCat.

#Preview("Paywall — standard") {
    PaywallView(onPurchase: { _ in .cancelled })
}

#Preview("Paywall — founding") {
    PaywallView(isFoundingEligible: true, onPurchase: { _ in .cancelled })
}
