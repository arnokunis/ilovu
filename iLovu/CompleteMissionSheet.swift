// CompleteMissionSheet.swift
// The "save a memory of this date" flow that appears when the user
// taps Mark Complete inside MissionDetailView. Lets them attach a
// photo (optional rating + note), or skip the photo entirely and
// just complete the mission.
//
// This view doesn't bump the spark score or change the mission
// status itself — it produces a Memory? and hands it back to the
// parent via onFinish, which keeps responsibilities clean:
//   • This sheet:        create-a-Memory UI
//   • MissionDetailView: write Memory + Mission + sparkScore changes

import SwiftUI
import PhotosUI

struct CompleteMissionSheet: View {

    // What we're saving a memory of. Just need the card's emoji and
    // title for display — the Memory itself snapshots them.
    let mission: Mission

    // Called when the user finishes. Memory is non-nil if they picked
    // a photo and chose Save Memory; nil if they tapped Skip For Now.
    // Either case completes the mission upstream.
    let onFinish: (Memory?) -> Void

    @Environment(\.dismiss) private var dismiss

    // The PhotosPicker hands us back a PhotosPickerItem. We then load
    // it asynchronously as Data and compress before storing.
    @State private var selectedItem: PhotosPickerItem?

    // The compressed JPEG we'll store on the Memory. Nil until the
    // user picks a photo and we finish processing it.
    @State private var photoData: Data?

    // 0 = unrated. Optional<Int> in the Memory model — we map 0 → nil
    // when saving so the data model stays clean.
    @State private var rating: Int = 0
    @State private var note: String = ""

    // Brief loading state while we decode + compress the picked photo.
    @State private var isProcessingPhoto: Bool = false

    // Own LocationManager so we can stamp WHERE the date happened onto the memory
    // (for the Memory Map). Its init auto-starts a fix ONLY if location permission
    // was already granted (e.g. via Near You) — so no new prompt appears here. By
    // the time the user picks a photo + writes a note, a fix has usually arrived;
    // we store coordinates only when `hasFix` is true (never the London fallback).
    @State private var locationManager = LocationManager()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    headerCard
                    photoSection
                    if photoData != nil {
                        ratingSection
                        noteSection
                    }
                    actionButtons
                }
                .padding(20)
            }
            .background(Color.blushCream.ignoresSafeArea())
            .navigationTitle("Save a Memory")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.gray)
                }
            }
        }
        // PhotosPicker writes the picked item here; we react by
        // decoding + compressing it.
        .onChange(of: selectedItem) { _, newItem in
            loadPhoto(from: newItem)
        }
    }

    // MARK: - Header

    private var headerCard: some View {
        VStack(spacing: 10) {
            Text(mission.card.emoji)
                .font(.system(size: 48))
            Text(mission.card.title)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color.deepRose)
                .multilineTextAlignment(.center)
            Text("Capture how it went 💕")
                .font(.system(size: 13))
                .foregroundStyle(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .louvShadow()
    }

    // MARK: - Photo

    private var photoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Photo")

            if let photoData, let image = UIImage(data: photoData) {
                // Preview of the picked photo.
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity)
                    .frame(height: 240)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                PhotosPicker(selection: $selectedItem, matching: .images) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Choose different photo")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(Color.louvCoral)
                }
            } else {
                // Empty-state picker tile.
                PhotosPicker(selection: $selectedItem, matching: .images) {
                    VStack(spacing: 12) {
                        if isProcessingPhoto {
                            ProgressView()
                                .tint(Color.louvCoral)
                        } else {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.system(size: 36))
                                .foregroundStyle(Color.louvCoral)
                            Text("Choose a photo")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Color.louvCoral)
                            Text("From your library")
                                .font(.system(size: 12))
                                .foregroundStyle(.gray)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 180)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(
                                Color.louvCoral.opacity(0.35),
                                style: StrokeStyle(lineWidth: 1.5, dash: [5])
                            )
                    )
                }
            }
        }
    }

    // MARK: - Rating

    private var ratingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Rate it (optional)")
            HStack(spacing: 12) {
                ForEach(1...5, id: \.self) { star in
                    Button {
                        withAnimation(LouvAnimation.spring) {
                            // Tapping the currently-set top star clears
                            // the rating; otherwise sets it to that star.
                            rating = (rating == star) ? 0 : star
                        }
                        UISelectionFeedbackGenerator().selectionChanged()
                    } label: {
                        Image(systemName: rating >= star ? "star.fill" : "star")
                            .font(.system(size: 30))
                            .foregroundStyle(rating >= star ? Color.louvCoral : Color.gray.opacity(0.35))
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .louvShadow()
    }

    // MARK: - Note

    private var noteSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("A note (optional)")
            TextField("What was special about today?", text: $note, axis: .vertical)
                .lineLimit(2...5)
                .font(.system(size: 15))
                // Explicit dark text + tint so it stays readable on the fixed-light
                // field in dark mode (default .primary would render white).
                .foregroundStyle(Color.deepRose)
                .tint(Color.louvCoral)
                .padding(.vertical, 12)
                .padding(.horizontal, 14)
                .background(Color.blushCream)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .louvShadow()
    }

    // MARK: - Actions

    private var actionButtons: some View {
        VStack(spacing: 12) {
            // Primary: save the memory and complete. Disabled until a
            // photo is picked — otherwise the button name is a lie.
            Button(action: completeWithMemory) {
                Text("Save Memory & Complete")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(LouvGradient.coral)
                    .clipShape(Capsule())
                    .louvShadow()
            }
            .buttonStyle(.plain)
            .disabled(photoData == nil)
            .opacity(photoData == nil ? 0.5 : 1)

            // Secondary: skip the photo, still complete the mission.
            Button {
                onFinish(nil)
                dismiss()
            } label: {
                Text("Skip for now")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.gray)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 4)
    }

    // MARK: - Photo loading & compression

    // PhotosPicker hands us a PhotosPickerItem — a token we can load
    // the image data from. We load + compress on a background task so
    // the UI stays responsive on large images.
    private func loadPhoto(from item: PhotosPickerItem?) {
        guard let item else { return }
        isProcessingPhoto = true
        Task {
            let compressed = await compressPickedItem(item)
            await MainActor.run {
                self.photoData = compressed
                self.isProcessingPhoto = false
            }
        }
    }

    // Why compress?
    // Photos from a modern phone are 3-6 MB each. Stored uncompressed,
    // a couple's worth of memories would balloon UserDefaults and slow
    // app launch. JPEG at 60% quality is visually indistinguishable
    // from the original at this size, and resizing to 1024px on the
    // longest side covers every display we'd ever show it on.
    private func compressPickedItem(_ item: PhotosPickerItem) async -> Data? {
        guard
            let raw = try? await item.loadTransferable(type: Data.self),
            let image = UIImage(data: raw)
        else { return nil }

        let maxDim: CGFloat = 1024
        let size = image.size
        let scale = min(maxDim / size.width, maxDim / size.height, 1.0)

        // Only resize if the photo is bigger than 1024 on its longer side.
        let targetSize = scale < 1.0
            ? CGSize(width: size.width * scale, height: size.height * scale)
            : size

        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        return resized.jpegData(compressionQuality: 0.6)
    }

    // MARK: - Save

    private func completeWithMemory() {
        guard let photoData else { return }
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        // Stamp the location only if we have a genuine fix — otherwise leave it
        // nil (no pin) rather than storing the London fallback.
        let coord = locationManager.hasFix ? locationManager.coordinate : nil
        let memory = Memory(
            id: UUID(),
            dateCompleted: Date(),
            cardTitle: mission.card.title,
            cardEmoji: mission.card.emoji,
            photoData: photoData,
            rating: rating > 0 ? rating : nil,
            note: trimmedNote.isEmpty ? nil : trimmedNote,
            latitude: coord?.latitude,
            longitude: coord?.longitude
        )
        onFinish(memory)
        dismiss()
    }

    // MARK: - Shared

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.gray)
            .textCase(.uppercase)
            .tracking(0.5)
    }
}

#Preview {
    CompleteMissionSheet(
        mission: Mission(from: SampleCards.all[0])
    ) { _ in }
}
