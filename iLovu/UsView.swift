// UsView.swift
// The Memory Vault — the "Us" tab. A scrollable history of every
// completed date the couple has saved a photo for. Top of the
// dopamine loop: a couple with a vault full of memories has a
// reason to keep the app installed long after the novelty fades.

import SwiftUI

struct UsView: View {

    @Environment(MemoryStore.self) private var memoryStore

    // Drives the full-screen memory viewer when a card is tapped.
    @State private var selectedMemory: Memory?

    var body: some View {
        ZStack {
            Color.blushCream.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    header

                    if memoryStore.memories.isEmpty {
                        emptyState
                    } else {
                        memoryList
                    }
                }
            }
        }
        .fullScreenCover(item: $selectedMemory) { memory in
            MemoryDetailView(memory: memory)
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

    // MARK: - Memory list

    private var memoryList: some View {
        VStack(spacing: 16) {
            ForEach(memoryStore.sortedByDate) { memory in
                memoryCard(memory)
            }
        }
        .padding(20)
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
                .font(.system(size: 64))
                .foregroundStyle(Color.louvCoral.opacity(0.55))
                .padding(.top, 60)

            Text("Your first memory is waiting 💕")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Color.deepRose)
                .multilineTextAlignment(.center)

            Text("Complete a mission to start your story")
                .font(.system(size: 15))
                .foregroundStyle(.gray)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 32)
        .padding(.bottom, 60)
    }
}

#Preview {
    UsView()
        .environment(MemoryStore())
}
