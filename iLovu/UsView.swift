// UsView.swift
// The Memory Vault — the "Us" tab. A scrollable history of every
// completed date the couple has saved a photo for. Top of the
// dopamine loop: a couple with a vault full of memories has a
// reason to keep the app installed long after the novelty fades.

import SwiftUI
import PhotosUI

struct UsView: View {

    @Environment(MemoryStore.self) private var memoryStore

    // App-level auth state, used by the Sign Out button below.
    @Environment(AuthState.self) private var authState

    // The user's local profile photo, shown in the profile row.
    @Environment(ProfileStore.self) private var profileStore

    // The shared couple link — source of the couple photo path + version, and
    // the write path (setCouplePhoto) when either partner sets/changes it.
    @Environment(CoupleService.self) private var coupleService

    // The couple-photo picker + its in-flight upload state.
    @State private var couplePhotoItem: PhotosPickerItem?
    @State private var isUploadingCouplePhoto = false

    // The user's display name (same key as onboarding + the Home greeting).
    @AppStorage("userName") private var userName: String = ""

    // Drives the full-screen memory viewer when a card is tapped.
    @State private var selectedMemory: Memory?

    // Presents the partner-pairing sheet (create / redeem an invite).
    @State private var showPairing = false

    // Presents the edit-name / edit-photo sheet.
    @State private var showEditProfile = false

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
        .sheet(isPresented: $showEditProfile) {
            EditProfileView()
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 6) {
            // Shared couple photo — only meaningful once paired (it lives on the
            // couple doc). Either partner can set/change it.
            if coupleService.coupleId != nil {
                couplePhotoView
                    .padding(.bottom, 10)
            }

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

    // MARK: - Couple photo
    // Circular, tappable (PhotosPicker). Shows the shared photo when set, a warm
    // "add a photo of you two" prompt when not. Either partner can change it; a
    // change overwrites the single profile.jpg and bumps couplePhotoUpdatedAt.

    private var couplePhotoView: some View {
        PhotosPicker(selection: $couplePhotoItem, matching: .images) {
            ZStack {
                if let path = coupleService.couplePhotoPath, !path.isEmpty {
                    CachedStorageImage(path: path,
                                       version: coupleService.couplePhotoVersion) {
                        couplePhotoPlaceholder
                    }
                    .frame(width: 96, height: 96)
                    .clipShape(Circle())
                } else {
                    couplePhotoPlaceholder
                        .frame(width: 96, height: 96)
                        .clipShape(Circle())
                }

                if isUploadingCouplePhoto {
                    Circle()
                        .fill(.black.opacity(0.35))
                        .frame(width: 96, height: 96)
                    ProgressView().tint(.white)
                }
            }
            .overlay(Circle().stroke(.white, lineWidth: 3))
            // Small camera badge so the photo reads as editable.
            .overlay(alignment: .bottomTrailing) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.deepRose)
                    .padding(7)
                    .background(Circle().fill(.white))
                    .offset(x: 2, y: 2)
            }
        }
        .buttonStyle(.plain)
        .disabled(isUploadingCouplePhoto)
        .onChange(of: couplePhotoItem) { _, item in
            guard let item else { return }
            Task { await uploadCouplePhoto(item) }
        }
    }

    private var couplePhotoPlaceholder: some View {
        ZStack {
            Color.white.opacity(0.22)
            VStack(spacing: 4) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(.white)
                Text("Add a photo\nof you two 💕")
                    .font(.system(size: 11, weight: .semibold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
            }
        }
    }

    // Downscale to the shared photo budget (1024px / 0.7) and upload via the
    // couple service. Errors are swallowed for now — the picker stays put so the
    // user can simply try again.
    private func uploadCouplePhoto(_ item: PhotosPickerItem) async {
        isUploadingCouplePhoto = true
        defer { isUploadingCouplePhoto = false }

        guard let raw = try? await item.loadTransferable(type: Data.self),
              let jpeg = ImageDownscaler.downscaledJPEG(from: raw, maxEdge: 1024, quality: 0.7)
        else { return }

        try? await coupleService.setCouplePhoto(jpegData: jpeg)
        couplePhotoItem = nil
    }

    // MARK: - Content below header
    // Daily question always shown; the vault below either lists
    // memories or shows the warm "first memory waiting" empty state.

    private var contentBelowHeader: some View {
        VStack(spacing: 16) {
            profileRow

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

    // MARK: - Profile (name + photo)
    // Tappable row showing the user's avatar + name, opening the edit sheet.
    // The entry point for setting a name after skipping onboarding, or changing
    // either later.

    private var profileRow: some View {
        Button {
            showEditProfile = true
        } label: {
            HStack(spacing: 14) {
                avatar
                    .frame(width: 52, height: 52)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(userName.isEmpty ? "Add your name" : userName)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Color.deepRose)
                    Text("Edit name & photo")
                        .font(.system(size: 13))
                        .foregroundStyle(.gray)
                }

                Spacer()

                Image(systemName: "pencil.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(Color.louvCoral)
            }
            .padding(16)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .louvShadow()
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var avatar: some View {
        if let data = profileStore.photoData, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                LouvGradient.coral
                Text(userName.trimmingCharacters(in: .whitespaces).isEmpty
                     ? "💕"
                     : String(userName.trimmingCharacters(in: .whitespaces).prefix(1)).uppercased())
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
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
        .environment(ProfileStore())
}
