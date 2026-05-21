// NearYouView.swift
// Placeholder for the Near You tab. Will eventually show local date
// venues, events, and pop-ups based on location. Stubbed for now.

import SwiftUI

struct NearYouView: View {
    var body: some View {
        ZStack {
            Color.blushCream.ignoresSafeArea()

            VStack(spacing: 12) {
                Text("Near You")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(Color.deepRose)

                Text("Local events coming soon")
                    .font(.system(size: 16))
                    .foregroundStyle(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
        }
    }
}

#Preview {
    NearYouView()
}
