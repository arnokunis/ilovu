// YearInReview.swift
// An auto-generated, shareable recap of the couple's year — dates completed, days
// together, and the emoji of everywhere they went. Reuses the memory-share-card
// render path (ImageRenderer → PNG → native ShareSheet). Extremely viral in
// December/January; on-brand ("Show it. Don't just say it."). Reads MemoryStore +
// CoupleService only — no backend.

import SwiftUI

// MARK: - The shareable card (9:16 story shape)

struct YearInReviewCard: View {

    let year: Int
    let dateCount: Int
    let daysTogether: Int?
    let partnerName: String?
    let emojis: [String]

    static let size = CGSize(width: 360, height: 640)

    var body: some View {
        ZStack {
            LouvGradient.coral

            VStack(spacing: 0) {
                Text("OUR YEAR ✨")
                    .font(.system(size: 15, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.top, 8)

                Spacer()

                Text("\(dateCount)")
                    .font(.system(size: 96, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)

                Text(dateCount == 1 ? "date together" : "dates together")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)

                if let daysTogether {
                    Text(subtitle(days: daysTogether, partner: partnerName))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.9))
                        .padding(.top, 6)
                }

                if !emojis.isEmpty {
                    Text(emojis.joined(separator: "  "))
                        .font(.system(size: 26))
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .padding(.top, 26)
                        .padding(.horizontal, 20)
                }

                Spacer()

                HStack(spacing: 6) {
                    Text("♡").font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
                    Text("iLovu").font(.system(size: 17, weight: .heavy, design: .rounded)).foregroundStyle(.white)
                    Spacer()
                    Text("Show it. Don't just say it.")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.75))
                }
                .padding(.bottom, 4)
            }
            .padding(28)
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .clipped()
    }

    private func subtitle(days: Int, partner: String?) -> String {
        if let partner, !partner.isEmpty { return "\(days) days with \(partner) 💕" }
        return "\(days) days together 💕"
    }
}

// MARK: - The viewer + share flow

struct YearInReviewView: View {

    @Environment(MemoryStore.self) private var memoryStore
    @Environment(CoupleService.self) private var coupleService
    @Environment(\.dismiss) private var dismiss

    @State private var shareItem: ShareItem?

    private struct ShareItem: Identifiable {
        let id = UUID()
        let url: URL
    }

    // On-screen preview scale — fits the 360-wide card on any phone.
    private let previewScale: CGFloat = 0.82

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    card
                        .frame(width: YearInReviewCard.size.width, height: YearInReviewCard.size.height)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .scaleEffect(previewScale)
                        .frame(width: YearInReviewCard.size.width * previewScale,
                               height: YearInReviewCard.size.height * previewScale)
                        .louvShadow()
                        .padding(.top, 12)

                    shareButton
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 24)
            }
            .background(Color.blushCream.ignoresSafeArea())
            .navigationTitle("Year in Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color.louvCoral)
                        .fontWeight(.semibold)
                }
            }
            .sheet(item: $shareItem) { item in
                ShareSheet(items: [item.url])
            }
        }
    }

    private var card: YearInReviewCard {
        YearInReviewCard(
            year: currentYear,
            dateCount: dateCount,
            daysTogether: coupleService.couple?.daysTogether(),
            partnerName: coupleService.partnerDisplayName,
            emojis: topEmojis
        )
    }

    private var shareButton: some View {
        Button { share() } label: {
            HStack(spacing: 6) {
                Image(systemName: "square.and.arrow.up").font(.system(size: 15, weight: .semibold))
                Text("Share our year").font(.system(size: 16, weight: .semibold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(LouvGradient.coral)
            .clipShape(Capsule())
            .louvShadow()
        }
        .buttonStyle(.plain)
    }

    // MARK: - Stats

    private var currentYear: Int {
        Calendar.current.component(.year, from: Date())
    }

    /// Dates completed this calendar year; falls back to all-time if the year is
    /// empty (a young couple still gets a card worth sharing).
    private var dateCount: Int {
        let thisYear = memoryStore.memories.filter {
            Calendar.current.component(.year, from: $0.dateCompleted) == currentYear
        }.count
        return thisYear > 0 ? thisYear : memoryStore.memories.count
    }

    /// Up to 8 distinct emojis from the most recent memories.
    private var topEmojis: [String] {
        var seen = Set<String>()
        var result: [String] = []
        for memory in memoryStore.sortedByDate {
            let emoji = memory.cardEmoji
            if !emoji.isEmpty, !seen.contains(emoji) {
                seen.insert(emoji)
                result.append(emoji)
            }
            if result.count == 8 { break }
        }
        return result
    }

    // MARK: - Render + share

    @MainActor
    private func share() {
        let renderer = ImageRenderer(content: card)
        renderer.scale = 3   // ~1080×1920, story resolution
        guard let uiImage = renderer.uiImage,
              let data = uiImage.pngData() else { return }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ilovu-year-in-review.png")
        do {
            try data.write(to: url, options: .atomic)
            AppAnalytics.log("memory_shared")
            shareItem = ShareItem(url: url)
        } catch { }
    }
}
