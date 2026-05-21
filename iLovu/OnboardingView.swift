// OnboardingView.swift
// The first-launch experience: three swipeable intro screens that introduce
// the app, explain the swipe-and-match concept, and collect a name + vibe.
//
// Lives behind an @AppStorage("hasCompletedOnboarding") flag so it only
// shows once per install. ContentView swaps to SwipeView the moment the
// user finishes the third screen.

import SwiftUI

// MARK: - Vibe
// Five fixed personality buckets the user picks on screen 3.
// Stored as a raw String in @AppStorage so it survives app launches.
enum Vibe: String, CaseIterable, Identifiable {
    case romantic    = "Romantic"
    case adventurous = "Adventurous"
    case foodies     = "Foodies"
    case creative    = "Creative"
    case homebody    = "Homebody"

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
                Text("Reignite Your Spark")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(Color.deepRose)
                    .multilineTextAlignment(.center)

                Text("Daily date missions, designed for two. Swipe together, do things together.")
                    .font(.system(size: 16))
                    .foregroundStyle(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            HStack(spacing: 12) {
                featurePill(systemImage: "heart.fill",   label: "Connect")
                featurePill(systemImage: "calendar",     label: "Plan")
                featurePill(systemImage: "star.fill",    label: "Remember")
            }
            .padding(.horizontal, 24)

            Spacer()

            VStack(spacing: 14) {
                PrimaryButton(title: "Get Started →", action: onNext)

                // Concatenated Text lets us color "Sign in" differently
                // without splitting into two separate views.
                (Text("Already have an account? ").foregroundStyle(.gray)
                 + Text("Sign in").foregroundStyle(Color.louvCoral).fontWeight(.semibold))
                    .font(.system(size: 14))
            }
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
                Text("Swipe. Match. Make it happen.")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(Color.deepRose)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                Text("Both of you swipe through date ideas on your own phones. When you both like the same one — it's a match, and it becomes a plan.")
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
                    partnerCard(label: "You")
                    partnerCard(label: "Your partner")
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
            Text("It's a Match!")
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
                Text("Tell us about you two")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(Color.deepRose)
                    .multilineTextAlignment(.center)

                Text("So we can tailor the ideas we send your way.")
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

                // FlowLayout wraps the pills to a second row on narrower phones
                // (five vibes won't fit one row on an iPhone SE).
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

    private func vibePill(_ vibe: Vibe) -> some View {
        let isSelected = userVibe == vibe.rawValue

        return Button {
            withAnimation(LouvAnimation.spring) {
                userVibe = vibe.rawValue
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
// Used by the vibe pill grid so five labels of varying widths wrap cleanly.
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
