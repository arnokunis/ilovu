// EditProfileView.swift
// Lets a user set or change their display name and profile photo any time —
// the missing "I skipped onboarding / want to change it" path. Presented as a
// sheet from the Us tab.
//
// Persistence split:
//   • name  -> @AppStorage("userName") (local, drives the Home greeting) AND
//              CoupleService.setDisplayName so the partner sees it on the couple doc.
//   • photo -> ProfileStore (local only for now; partner-visible photos need
//              Firebase Storage, deferred).
//
// The photo is downscaled before saving so we never stash a multi-MB original in
// UserDefaults.

import SwiftUI
import PhotosUI

struct EditProfileView: View {

    @Environment(ProfileStore.self) private var profileStore
    @Environment(CoupleService.self) private var couples
    @Environment(\.dismiss) private var dismiss

    // Same key onboarding + Home use, so an edit here updates the greeting too.
    @AppStorage("userName") private var userName: String = ""

    // Working copies — committed only on Save, so Cancel discards cleanly.
    @State private var draftName: String = ""
    @State private var draftPhoto: Data?
    @State private var pickerItem: PhotosPickerItem?
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.blushCream.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 28) {
                        photoSection
                        nameSection
                    }
                    .padding(24)
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.louvCoral)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.louvCoral)
                        .disabled(isSaving)
                }
            }
        }
        .onAppear {
            draftName = userName
            draftPhoto = profileStore.photoData
        }
        // Load + downscale the picked image into the working copy.
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    draftPhoto = Self.downscaledJPEG(data) ?? data
                }
            }
        }
    }

    // MARK: - Photo

    private var photoSection: some View {
        VStack(spacing: 14) {
            avatar
                .frame(width: 120, height: 120)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.white, lineWidth: 3))
                .louvShadow()

            PhotosPicker(selection: $pickerItem, matching: .images) {
                Text(draftPhoto == nil ? "Add a photo" : "Change photo")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.louvCoral)
            }

            if draftPhoto != nil {
                Button(role: .destructive) {
                    draftPhoto = nil
                    pickerItem = nil
                } label: {
                    Text("Remove photo")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.passRed)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 12)
    }

    @ViewBuilder
    private var avatar: some View {
        if let data = draftPhoto, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                LouvGradient.coral
                Text(initial)
                    .font(.system(size: 48, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
    }

    // First letter of the draft name for the placeholder avatar, or a heart.
    private var initial: String {
        let trimmed = draftName.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? "💕" : String(trimmed.prefix(1)).uppercased()
    }

    // MARK: - Name

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your name")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.gray)

            TextField("e.g. Alex", text: $draftName)
                .textFieldStyle(.plain)
                .font(.system(size: 17))
                // Explicit dark text — the field sits on a light background, so
                // the default label color is invisible (white) in dark mode.
                .foregroundStyle(Color.deepRose)
                .tint(Color.louvCoral)
                .padding(.vertical, 14)
                .padding(.horizontal, 16)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .louvShadow()

            Text("Your partner sees your name. Your photo stays on this device for now.")
                .font(.system(size: 12))
                .foregroundStyle(.gray)
                .padding(.top, 2)
        }
    }

    // MARK: - Save

    private func save() async {
        isSaving = true
        let trimmed = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        userName = trimmed                       // local (Home greeting)
        profileStore.setPhoto(draftPhoto)        // local photo
        await couples.setDisplayName(trimmed)    // sync to partner via couple doc
        isSaving = false
        dismiss()
    }

    // MARK: - Image downscaling

    /// Shrinks an image to a profile-sized JPEG so UserDefaults never holds the
    /// full-resolution original. ~512px max edge, 0.8 quality — plenty for an
    /// avatar, a few tens of KB on disk.
    private static func downscaledJPEG(_ data: Data, maxEdge: CGFloat = 512) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let longest = max(image.size.width, image.size.height)
        let scale = longest > maxEdge ? maxEdge / longest : 1
        let target = CGSize(width: image.size.width * scale, height: image.size.height * scale)

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: target, format: format)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        return resized.jpegData(compressionQuality: 0.8)
    }
}

#Preview {
    EditProfileView()
        .environment(ProfileStore())
        .environment(CoupleService())
}
