// SwipeStamp.swift
// The "LIKE" / "NOPE" stamp overlaid on the top card as the user
// drags it. Used by both SwipeView (date cards) and NearYouView
// (local events) so they look and feel identical.
//
// The opacity fade-in is owned by the parent — this view just renders
// the stamp itself. Caller does `.opacity(progressTowardThreshold)`.

import SwiftUI

struct SwipeStamp: View {
    let text: String
    let color: Color
    let rotation: Double

    var body: some View {
        Text(text)
            .font(.system(size: 36, weight: .heavy))
            .tracking(2)
            .foregroundStyle(color)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(color, lineWidth: 3)
            )
            .rotationEffect(.degrees(rotation))
            .padding(24)
    }
}
