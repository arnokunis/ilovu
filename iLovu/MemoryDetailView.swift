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
    @Environment(CoupleService.self) private var coupleService
    @Environment(\.dismiss) private var dismiss

    // Re-pick state for replacing the proof photo.
    @State private var pickerItem: PhotosPickerItem?

    // Share-card state: the rendered PNG to hand the share sheet, plus a flag for
    // the (brief) render so the button can show progress.
    @State private var shareItem: ShareItem?
    @State private var isPreparingShare = false

    // Identifiable wrapper so the share sheet presents via `.sheet(item:)`.
    private struct ShareItem: Identifiable {
        let id = UUID()
        let url: URL
    }

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

                    shareButton

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
        // Native share sheet for the rendered memory card.
        .sheet(item: $shareItem) { item in
            ShareSheet(items: [item.url])
        }
    }

    // The growth feature: renders this memory into a branded, Story-shaped card
    // and opens the native share sheet. Reads the existing Vault only.
    private var shareButton: some View {
        Button {
            Task { await prepareShare() }
        } label: {
            HStack(spacing: 6) {
                if isPreparingShare {
                    ProgressView().tint(.white)
                } else {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 15, weight: .semibold))
                }
                Text(isPreparingShare ? "Preparing…" : "Share this memory")
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 22)
            .padding(.vertical, 12)
            .background(LouvGradient.coral)
            .clipShape(Capsule())
            .louvShadow()
        }
        .disabled(isPreparingShare)
    }

    // MARK: - Share rendering

    /// Loads the photo, renders the share card to a PNG, and presents the sheet.
    /// Runs on the main actor (ImageRenderer requirement); the image load awaits
    /// off the render.
    @MainActor
    private func prepareShare() async {
        isPreparingShare = true
        defer { isPreparingShare = false }

        let photo = await loadImage(for: current)
        let days = coupleService.couple?.daysTogether().map { "\($0) days together" }

        let card = MemoryShareCard(
            image: photo,
            emoji: current.cardEmoji,
            title: current.cardTitle,
            dateText: current.dateCompleted.formatted(date: .abbreviated, time: .omitted),
            ordinalText: ordinalText(for: current),
            daysText: days
        )

        let renderer = ImageRenderer(content: card)
        renderer.scale = 3   // ~1080×1920, Instagram-Story resolution
        guard let uiImage = renderer.uiImage,
              let data = uiImage.pngData() else { return }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ilovu-memory.png")
        do {
            try data.write(to: url, options: .atomic)
            AppAnalytics.log("memory_shared")
            shareItem = ShareItem(url: url)
        } catch {
            // Silent: a failed temp write just means no share sheet this tap.
        }
    }

    /// The memory's proof photo: local bytes first (instant), else the
    /// download-once ImageCache. nil → the card renders its coral fallback.
    private func loadImage(for memory: Memory) async -> UIImage? {
        if let data = memory.photoData, let image = UIImage(data: data) { return image }
        guard let path = memory.storagePath else { return nil }
        return await ImageCache.shared.image(forPath: path, version: String(memory.photoVersion))
    }

    /// "Our 14th date" from this memory's position in the vault (oldest = 1st).
    /// nil if the memory isn't in the store (e.g. previews).
    private func ordinalText(for memory: Memory) -> String? {
        let ordered = memoryStore.memories.sorted { $0.dateCompleted < $1.dateCompleted }
        guard let index = ordered.firstIndex(where: { $0.id == memory.id }) else { return nil }
        return "Our \(Self.ordinal(index + 1)) date"
    }

    /// 1 → "1st", 2 → "2nd", 11 → "11th", 22 → "22nd", etc.
    private static func ordinal(_ n: Int) -> String {
        let suffix: String
        switch (n % 100, n % 10) {
        case (11...13, _): suffix = "th"
        case (_, 1):       suffix = "st"
        case (_, 2):       suffix = "nd"
        case (_, 3):       suffix = "rd"
        default:           suffix = "th"
        }
        return "\(n)\(suffix)"
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
