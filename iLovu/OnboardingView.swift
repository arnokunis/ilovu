// OnboardingView.swift
// The first-launch experience: three swipeable intro screens that introduce
// the app, explain the swipe-and-match concept, and collect a name + vibe.
//
// Lives behind an @AppStorage("hasCompletedOnboarding") flag so it only
// shows once per install. ContentView swaps to SwipeView the moment the
// user finishes the third screen.

import SwiftUI

// MARK: - Vibe
// Personality buckets the user picks on screen 3. Multi-select — pick as many
// as fit. Stored as a comma-joined raw String in @AppStorage so it survives app
// launches (and stays backward-compatible with the old single-value storage).
enum Vibe: String, CaseIterable, Identifiable {
    case romantic    = "Romantic"
    case adventurous = "Adventurous"
    case foodies     = "Foodies"
    case creative    = "Creative"
    case homebody    = "Homebody"
    case cosy        = "Cosy"
    case spontaneous = "Spontaneous"

    var id: String { rawValue }
}

// MARK: - OnboardingView
// The container. Owns the current page index and the completion flag,
// hosts the TabView, and renders our custom page dots below it.
struct OnboardingView: View {

    // Flipped to true when the user taps "Start Swiping →" on screen 3.
    // ContentView watches this and swaps in SwipeView when it's true.
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false

    @State private var currentPage: Int = 0
    private let pageCount = 3

    var body: some View {
        ZStack {
            // The same warm cream background the rest of the app uses.
            Color.blushCream.ignoresSafeArea()

            VStack(spacing: 0) {
                // TabView in .page style turns into a horizontally-swipeable
                // pager. We hide its native dots and draw our own below so
                // they match the brand palette and stay visible on cream.
                TabView(selection: $currentPage) {
                    WelcomeScreen(onNext: advance).tag(0)
                    HowItWorksScreen(onNext: advance).tag(1)
                    ProfileScreen(onComplete: complete).tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                pageDots
                    .padding(.bottom, 24)
            }
        }
    }

    // MARK: - Page Dots
    private var pageDots: some View {
        HStack(spacing: 8) {
            ForEach(0..<pageCount, id: \.self) { index in
                Circle()
                    .fill(index == currentPage ? Color.louvCoral : Color.deepRose.opacity(0.2))
                    .frame(width: 8, height: 8)
                    .animation(LouvAnimation.spring, value: currentPage)
            }
        }
    }

    // MARK: - Navigation helpers

    private func advance() {
        withAnimation(LouvAnimation.spring) {
            currentPage = min(currentPage + 1, pageCount - 1)
        }
    }

    private func complete() {
        // withAnimation so ContentView's transition from Onboarding → Swipe
        // fades smoothly instead of cutting hard.
        withAnimation(.easeInOut(duration: 0.35)) {
            hasCompletedOnboarding = true
        }
        AppAnalytics.log("onboarding_complete")
    }
}

// MARK: - WelcomeScreen
// Screen 1: brand wordmark, headline, three feature pills, primary CTA,
// and a soft "sign in" link.
private struct WelcomeScreen: View {
    let onNext: () -> Void

    var body: some View {
        VStack(spacing: 28) {
            Spacer().frame(height: 24)

            Text("iLovu")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Color.louvCoral)

            Spacer()

            VStack(spacing: 12) {
                Text("Good places, actually near you")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(Color.deepRose)
                    .multilineTextAlignment(.center)

                Text("Real places worth going, chosen from what is actually around you. Swipe, save the ones you like, and go.")
                    .font(.system(size: 16))
                    .foregroundStyle(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            HStack(spacing: 12) {
                featurePill(systemImage: "map.fill",     label: "Discover")
                featurePill(systemImage: "bookmark.fill", label: "Save")
                featurePill(systemImage: "figure.walk",  label: "Go")
            }
            .padding(.horizontal, 24)

            Spacer()

            // Sign-in happens BEFORE onboarding (ContentView routes signed-out
            // users to SignInView), so the welcome screen only needs the forward
            // CTA — no "already have an account?" link (you already signed in).
            PrimaryButton(title: "Get Started →", action: onNext)
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
        }
    }

    // One of the three small white cards in the feature row.
    private func featurePill(systemImage: String, label: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 22))
                .foregroundStyle(Color.louvCoral)
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.deepRose)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .louvShadow()
    }
}

// MARK: - HowItWorksScreen
// Screen 2: explains the swipe-and-match concept with a small visual
// of two mini cards joined by a coral heart.
private struct HowItWorksScreen: View {
    let onNext: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            Spacer().frame(height: 24)

            VStack(spacing: 12) {
                Text("Swipe. Save. Go.")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(Color.deepRose)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                Text("Swipe through places near you — cafés, restaurants, viewpoints, trails. Anything you like is saved to your list, with what it costs.")
                    .font(.system(size: 16))
                    .foregroundStyle(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()

            // The "matching" diagram: two phone-style cards both showing
            // the same date idea with a green ✓, an arrow pointing down,
            // and an "It's a Match!" badge underneath. Reads literally as
            // "you both picked the same thing → that's a match".
            VStack(spacing: 18) {
                HStack(spacing: 24) {
                    partnerCard(label: "Saved")
                    partnerCard(label: "Saved")
                }

                Image(systemName: "arrow.down")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Color.deepRose.opacity(0.4))

                matchBadge
            }

            Spacer()

            PrimaryButton(title: "Next →", action: onNext)
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
        }
    }

    // A miniature "phone" card. Both partners are shown swiping right on
    // the exact same idea ("Sunset Picnic"), with a green tick badge in
    // the top corner to signal approval.
    private func partnerCard(label: String) -> some View {
        VStack(spacing: 10) {
            VStack(spacing: 6) {
                Text("🌅")
                    .font(.system(size: 36))
                Text("Sunset Picnic")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.deepRose)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 6)
            }
            .frame(width: 104, height: 140)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .louvShadow()
            // Green check badge — clear "I liked this" signal. Sticking
            // out of the card's corner makes it read as a sticker/stamp.
            .overlay(alignment: .topTrailing) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 26))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, Color.matchGreen)
                    .background(Circle().fill(Color.white))
                    .offset(x: 8, y: -8)
            }

            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.gray)
        }
    }

    // The "It's a Match!" celebration pill underneath the arrow.
    private var matchBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: "sparkles")
                .font(.system(size: 13, weight: .bold))
            Text("On your list")
                .font(.system(size: 15, weight: .bold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(LouvGradient.coral)
        .clipShape(Capsule())
        .louvShadow()
    }
}

// MARK: - ProfileScreen
// Screen 3: collect the user's name and vibe, then mark onboarding done.
private struct ProfileScreen: View {
    @AppStorage("userName") private var userName: String = ""
    @AppStorage("userVibe") private var userVibe: String = ""

    let onComplete: () -> Void

    var body: some View {
        VStack(spacing: 28) {
            Spacer().frame(height: 24)

            VStack(spacing: 12) {
                Text("What should we call you?")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(Color.deepRose)
                    .multilineTextAlignment(.center)

                Text("So the app feels like yours.")
                    .font(.system(size: 16))
                    .foregroundStyle(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Your name")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.gray)

                TextField("e.g. Alex", text: $userName)
                    .textFieldStyle(.plain)
                    .font(.system(size: 17))
                    // Explicit dark text — the field sits on a hardcoded light
                    // background, so the default label color is invisible (white)
                    // in dark mode.
                    .foregroundStyle(Color.deepRose)
                    .tint(Color.louvCoral)
                    .padding(.vertical, 14)
                    .padding(.horizontal, 16)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .louvShadow()
            }
            .padding(.horizontal, 24)

            VStack(alignment: .leading, spacing: 8) {
                Text("Your vibe")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.gray)

                // FlowLayout wraps the pills across rows on narrower phones
                // (the vibes won't fit one row on an iPhone SE). Multi-select:
                // tap to toggle each on/off.
                FlowLayout(spacing: 8) {
                    ForEach(Vibe.allCases) { vibe in
                        vibePill(vibe)
                    }
                }
            }
            .padding(.horizontal, 24)

            Spacer()

            PrimaryButton(title: "Start Swiping →", action: onComplete)
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
        }
    }

    // Selected vibes, parsed from the comma-joined @AppStorage string. Multi-
    // select, so this is a Set; an old single value ("Romantic") still parses.
    private var selectedVibes: Set<String> {
        Set(userVibe.split(separator: ",").map(String.init))
    }

    // Toggle a vibe in/out, then re-serialise in enum order so the stored
    // string stays deterministic regardless of tap order.
    private func toggleVibe(_ vibe: Vibe) {
        var current = selectedVibes
        if current.contains(vibe.rawValue) {
            current.remove(vibe.rawValue)
        } else {
            current.insert(vibe.rawValue)
        }
        userVibe = Vibe.allCases
            .filter { current.contains($0.rawValue) }
            .map(\.rawValue)
            .joined(separator: ",")
    }

    private func vibePill(_ vibe: Vibe) -> some View {
        let isSelected = selectedVibes.contains(vibe.rawValue)

        return Button {
            withAnimation(LouvAnimation.spring) {
                toggleVibe(vibe)
            }
        } label: {
            Text(vibe.rawValue)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(isSelected ? .white : .gray)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background {
                    if isSelected {
                        LouvGradient.coral
                    } else {
                        Color.white
                    }
                }
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(Color.deepRose.opacity(0.12), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - PrimaryButton
// The shared coral-gradient pill button used across all three screens.
// Centralised so size, padding, and shadow stay consistent.
private struct PrimaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(LouvGradient.coral)
                .clipShape(Capsule())
                .louvShadow()
        }
        .buttonStyle(.plain)
    }
}

// MARK: - FlowLayout
// A simple wrapping flow layout. Lays subviews left-to-right and breaks
// to a new row when the next subview would overflow the available width.
// Used by the vibe pill grid so the labels of varying widths wrap cleanly.
private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var totalHeight: CGFloat = 0
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowWidth + size.width > maxWidth, rowWidth > 0 {
                totalHeight += rowHeight + spacing
                rowWidth = size.width + spacing
                rowHeight = size.height
            } else {
                rowWidth += size.width + spacing
                rowHeight = max(rowHeight, size.height)
            }
        }
        totalHeight += rowHeight
        return CGSize(width: maxWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

#Preview {
    OnboardingView()
}
