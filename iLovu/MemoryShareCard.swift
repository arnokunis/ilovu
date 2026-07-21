// MemoryShareCard.swift
// A shareable, Instagram-Story-shaped (9:16) card generated from a completed
// Memory — the proof photo + a warm caption + a subtle iLovu wordmark. Every
// share is a FREE, on-brand impression of the app to the couple's social circle
// (the wordmark is the acquisition hook — this is the cheapest growth channel a
// couples app has). Rendered to an image via ImageRenderer and handed to the
// native share sheet. Reads ONLY the existing Memory Vault — no backend, no
// Firestore/schema touch.

import SwiftUI
import UIKit

struct MemoryShareCard: View {

    let image: UIImage?
    let emoji: String
    let title: String
    let dateText: String
    let ordinalText: String?   // e.g. "Our 14th date"
    let daysText: String?      // e.g. "428 days together"

    // Fixed design size; the renderer scales this 3× to ~1080×1920 (story res).
    static let size = CGSize(width: 360, height: 640)

    var body: some View {
        ZStack {
            // Background: the proof photo, or a warm coral fallback if the image
            // isn't available locally (e.g. a partner-synced memory not downloaded).
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                LouvGradient.coral
            }

            // Bottom scrim so the caption stays legible over any photo.
            LinearGradient(
                colors: [.clear, .black.opacity(0.35), .black.opacity(0.82)],
                startPoint: .top, endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 0) {
                Spacer()

                if let ordinalText {
                    Text(ordinalText.uppercased())
                        .font(.system(size: 13, weight: .bold))
                        .tracking(1.5)
                        .foregroundStyle(.white.opacity(0.9))
                        .padding(.bottom, 8)
                }

                Text("\(emoji) \(title)")
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    Text(dateText)
                    if let daysText {
                        Text("·")
                        Text(daysText)
                    }
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.85))
                .padding(.top, 10)

                // Brand footer — subtle but present. THIS is the acquisition hook.
                HStack(spacing: 6) {
                    Text("♡")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.louvCoral)
                    Text("iLovu")
                        .font(.system(size: 17, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                    Spacer()
                    Text("Show it. Don't just say it.")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                }
                .padding(.top, 24)
            }
            .padding(28)
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .clipped()
    }
}

// The native share sheet (UIActivityViewController) — reliable across Instagram
// Stories, Messages, Save Image, etc. ShareLink is finicky with a just-rendered
// image, so we share a real PNG file URL instead.
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
