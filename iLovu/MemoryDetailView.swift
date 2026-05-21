// MemoryDetailView.swift
// Full-screen viewer for a single Memory. Black background so the
// photo carries the whole frame, with the metadata (title, date,
// rating, note) stacked below it. A floating close button at the
// top-right dismisses back to the Memory Vault.

import SwiftUI

struct MemoryDetailView: View {
    let memory: Memory

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    if let image = UIImage(data: memory.photoData) {
                        // .fit so the entire photo is visible — no cropping
                        // in the detail view (unlike the vault thumbnail).
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: .infinity)
                    }

                    metadata
                        .padding(.bottom, 48)
                }
            }

            closeButton
                .padding(.top, 8)
                .padding(.trailing, 16)
        }
    }

    private var metadata: some View {
        VStack(spacing: 10) {
            Text(memory.cardEmoji)
                .font(.system(size: 44))

            Text(memory.cardTitle)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Text(memory.dateCompleted.formatted(date: .long, time: .omitted))
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.65))

            if let rating = memory.rating {
                HStack(spacing: 4) {
                    ForEach(0..<rating, id: \.self) { _ in
                        Image(systemName: "star.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(Color.louvCoral)
                    }
                }
                .padding(.top, 4)
            }

            if let note = memory.note {
                // Quoted to read as a journal entry rather than a label.
                Text("\u{201C}\(note)\u{201D}")
                    .font(.system(size: 17))
                    .italic()
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.top, 8)
            }
        }
    }

    private var closeButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 32))
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, .black.opacity(0.5))
        }
    }
}
