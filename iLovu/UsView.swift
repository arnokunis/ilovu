// UsView.swift
// The Memory Vault — the "Us" tab. A scrollable history of every
// completed date the couple has saved a photo for. Top of the
// dopamine loop: a couple with a vault full of memories has a
// reason to keep the app installed long after the novelty fades.

import SwiftUI

struct UsView: View {

    @Environment(MemoryStore.self) private var memoryStore

    // App-level auth state, used by the Sign Out button below.
    @Environment(AuthState.self) private var authState

    // Drives the full-screen memory viewer when a card is tapped.
    @State private var selectedMemory: Memory?

    // Presents the partner-pairing sheet (create / redeem an invite).
    @State private var showPairing = false

    var body: some View {
        ZStack {
            Color.blushCream.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    header
                    contentBelowHeader
                }
            }
        }
        .fullScreenCover(item: $selectedMemory) { memory in
            MemoryDetailView(memory: memory)
        }
        .sheet(isPresented: $showPairing) {
            PairingView()
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 6) {
            Text("Your Story Together 💕")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Text(memoryCountText)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 56)
        .padding(.bottom, 40)
        .background(
            LinearGradient(
                colors: [Color.deepRose, Color.louvCoral],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        // UnevenRoundedRectangle (iOS 16+) lets us round only the bottom
        // two corners so the header reads as a "drop down" panel.
        .clipShape(
            UnevenRoundedRectangle(
                cornerRadii: .init(bottomLeading: 32, bottomTrailing: 32),
                style: .continuous
            )
        )
        .ignoresSafeArea(edges: .top)
    }

    private var memoryCountText: String {
        let count = memoryStore.memories.count
        return count == 1 ? "1 memory" : "\(count) memories"
    }

    // MARK: - Content below header
    // Daily question always shown; the vault below either lists
    // memories or shows the warm "first memory waiting" empty state.

    private var contentBelowHeader: some View {
        VStack(spacing: 16) {
            connectButton

            DailyQuestionCard()

            if memoryStore.memories.isEmpty {
                emptyState
            } else {
                ForEach(memoryStore.sortedByDate) { memory in
                    memoryCard(memory)
                }
            }

            signOutButton
        }
        .padding(20)
    }

    // MARK: - Connect with partner

    private var connectButton: some View {
        Button {
            showPairing = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "heart.circle.fill")
                    .font(.system(size: 22))
                Text("Connect with your partner")
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(LouvGradient.coral)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .louvShadow()
        }
        .buttonStyle(.plain)
    }

    // MARK: - Sign Out

    private var signOutButton: some View {
        Button(role: .destructive) {
            authState.signOut()
        } label: {
            Text("Sign Out")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.passRed)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.white)
                .clipShape(Capsule())
                .louvShadow()
        }
        .buttonStyle(.plain)
        .padding(.top, 8)
    }

    private func memoryCard(_ memory: Memory) -> some View {
        Button {
            selectedMemory = memory
        } label: {
            VStack(spacing: 0) {
                photoThumbnail(for: memory)

                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Text(memory.cardEmoji)
                            .font(.system(size: 22))
                        Text(memory.cardTitle)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(Color.deepRose)
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)
                    }

                    HStack {
                        Text(memory.dateCompleted.formatted(date: .abbreviated, time: .omitted))
                            .font(.system(size: 13))
                            .foregroundStyle(.gray)

                        Spacer()

                        if let rating = memory.rating {
                            HStack(spacing: 2) {
                                ForEach(0..<rating, id: \.self) { _ in
                                    Image(systemName: "star.fill")
                                        .font(.system(size: 12))
                                        .foregroundStyle(Color.louvCoral)
                                }
                            }
                        }
                    }
                }
                .padding(16)
            }
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .louvShadow()
        }
        .buttonStyle(.plain)
    }

    // Thumbnail uses .fill + clipped so the photo always fills the
    // 4:3 frame without letterboxing, even if the source aspect is
    // wildly different. The detail view shows the uncropped version.
    @ViewBuilder
    private func photoThumbnail(for memory: Memory) -> some View {
        if let image = UIImage(data: memory.photoData) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(4/3, contentMode: .fill)
                .frame(maxWidth: .infinity)
                .frame(height: 220)
                .clipped()
        } else {
            // Defensive fallback if the saved Data somehow can't decode.
            Rectangle()
                .fill(Color.blushCream)
                .frame(height: 220)
                .overlay(
                    Image(systemName: "photo")
                        .font(.system(size: 36))
                        .foregroundStyle(Color.gray.opacity(0.5))
                )
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 56))
                .foregroundStyle(Color.louvCoral.opacity(0.55))
                .padding(.top, 32)

            Text("Your first memory is waiting 💕")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Color.deepRose)
                .multilineTextAlignment(.center)

            Text("Complete a mission to start your story")
                .font(.system(size: 15))
                .foregroundStyle(.gray)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 32)
    }
}

#Preview {
    UsView()
        .environment(MemoryStore())
        .environment(AuthState())
        .environment(CoupleService())
}
