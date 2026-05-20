//
//  ContentView.swift
//  iLovu
//
//  Created by Arnoldas on 20/05/2026.
//

import SwiftUI

struct ContentView: View {
    @State private var matchedCard: DateCard?

    var body: some View {
        SwipeView(matchedCard: $matchedCard)
            .fullScreenCover(item: $matchedCard) { card in
                MatchView(card: card)
            }
    }
}

#Preview {
    ContentView()
}
