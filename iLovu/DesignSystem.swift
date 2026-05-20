// DesignSystem.swift
// The single source of truth for iLovu's look and feel.
// Every color, gradient, shadow, and animation lives here so the whole
// app stays visually consistent. If we change the brand coral once here,
// it updates everywhere.

import SwiftUI

// MARK: - Colors
// We add our brand colors as static properties on Color so we can write
// `.louvCoral` anywhere SwiftUI expects a color (like `.foregroundStyle(.louvCoral)`).
extension Color {
    // Primary brand coral — used for hearts, accents, the "like" button.
    static let louvCoral = Color(red: 255/255, green: 107/255, blue: 107/255)   // #FF6B6B

    // Warmer orange — pairs with coral in our signature gradient.
    static let louvOrange = Color(red: 255/255, green: 142/255, blue: 83/255)   // #FF8E53

    // App background. A soft pinkish cream — never pure white,
    // because pure white feels clinical and we want the app to feel warm.
    static let blushCream = Color(red: 255/255, green: 245/255, blue: 243/255)  // #FFF5F3

    // Deeper rose — for headings or emphasis text on light backgrounds.
    static let deepRose = Color(red: 196/255, green: 69/255, blue: 105/255)     // #C44569

    // Apple-style success green — used when a couple gets a match.
    static let matchGreen = Color(red: 52/255, green: 199/255, blue: 89/255)    // #34C759
}

// MARK: - Gradients
// A namespace for reusable gradients. Call as `LouvGradient.coral`.
enum LouvGradient {
    // The signature coral→orange gradient at 135° (top-left to bottom-right).
    // Used on the like button, match screen background, etc.
    static let coral = LinearGradient(
        colors: [.louvCoral, .louvOrange],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - Animations
// A namespace so we always reach for the same spring across the app.
// Consistent motion = the app feels intentional, not random.
enum LouvAnimation {
    // Bouncy but controlled. Great for card swipes, button taps, modal entrances.
    static let spring = Animation.spring(response: 0.4, dampingFraction: 0.7)
}

// MARK: - Shadows
// A View modifier so any view can do `.louvShadow()` and get our
// signature soft, colored shadow — never harsh black.
extension View {
    func louvShadow() -> some View {
        self.shadow(
            color: Color.louvCoral.opacity(0.15),
            radius: 20,
            x: 0,
            y: 8
        )
    }
}
