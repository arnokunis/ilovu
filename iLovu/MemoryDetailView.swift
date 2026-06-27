// MemoryDetailView.swift
// Full-screen viewer for a single Memory. Black background so the
// photo carries the whole frame, with the metadata (title, date,
// rating, note) stacked below it. A floating close button at the
// top-right dismisses back to the Memory Vault.

import SwiftUI
import PhotosUI

struct MemoryDetailView: View {
    let memory: Memory

    @Environment(MemoryStore.self) private var memoryStore
    @Environment(\.dismiss) private var dismiss

    // Re-pick state for replacing the proof photo.
    @State private var pickerItem: PhotosPickerItem?

    // Bind display to the store's live entry (not the snapshot passed in) so a
    // photo replacement shows here immediately. Falls back to the snapshot if the
    // memory somehow isn't in the store (e.g. previews).
    private var current: Memory {
        memoryStore.memories.first { $0.id == memory.id } ?? memory
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    // .fit so the entire photo is visible — no cropping in the
                    // detail view (unlike the vault thumbnail). Bytes come from
                    // local capture or, for a partner-synced memory, Storage.
                    MemoryImage(memory: current) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: .infinity)
                    } placeholder: {
                        Color.black
                            .frame(height: 320)
                            .overlay(ProgressView().tint(.white))
                    }

                    changePhotoButton

                    metadata
                        .padding(.bottom, 48)
                }
            }

            closeButton
                .padding(.top, 8)
                .padding(.trailing, 16)
        }
        // Picked a replacement → downscale to the proof-photo budget (1024/0.6)
        // and hand it to the store, which bumps photoVersion + re-uploads.
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task {
                if let raw = try? await item.loadTransferable(type: Data.self),
                   let jpeg = ImageDownscaler.downscaledJPEG(from: raw, maxEdge: 1024, quality: 0.6) {
                    memoryStore.replacePhoto(id: memory.id, data: jpeg)
                }
                pickerItem = nil
            }
        }
    }

    // Lets the couple swap the proof photo on a completed memory anytime — the
    // mission's done, but the picture isn't locked.
    private var changePhotoButton: some View {
        PhotosPicker(selection: $pickerItem, matching: .images) {
            HStack(spacing: 6) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 14, weight: .semibold))
                Text("Change photo")
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(.white.opacity(0.15))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(.white.opacity(0.4), lineWidth: 1))
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
