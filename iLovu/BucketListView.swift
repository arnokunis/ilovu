// BucketListView.swift
// The couple's shared date wishlist — add your own ideas beyond the swipe deck,
// check them off when done. Presented as a sheet from the Us tab. Reads/writes
// BucketListStore, which syncs each change to the partner via BucketListService.

import SwiftUI

struct BucketListView: View {

    @Environment(BucketListStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var newTitle = ""
    @State private var selectedEmoji = "💡"
    @FocusState private var fieldFocused: Bool

    private let emojis = ["💡", "🍽️", "🌅", "🎬", "✈️", "🏔️", "🍷", "🎨", "🎶", "🏖️", "☕️", "🎡"]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.blushCream.ignoresSafeArea()
                VStack(spacing: 0) {
                    addBar
                    if store.items.isEmpty { emptyState } else { list }
                }
            }
            .navigationTitle("Date Wishlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color.louvCoral)
                        .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - Add bar (emoji picker + title field)

    private var addBar: some View {
        VStack(spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(emojis, id: \.self) { emoji in
                        Button { selectedEmoji = emoji } label: {
                            Text(emoji)
                                .font(.system(size: 22))
                                .frame(width: 40, height: 40)
                                .background(selectedEmoji == emoji ? Color.louvCoral.opacity(0.18) : Color.clear,
                                            in: Circle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }

            HStack(spacing: 10) {
                TextField("Add a date idea…", text: $newTitle)
                    .focused($fieldFocused)
                    .textFieldStyle(.plain)
                    .font(.system(size: 16))
                    .foregroundStyle(Color.deepRose)
                    .tint(Color.louvCoral)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 14)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 12))
                    .submitLabel(.done)
                    .onSubmit(addItem)

                Button(action: addItem) {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(LouvGradient.coral, in: Circle())
                }
                .disabled(newTitle.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 14)
    }

    // MARK: - List

    private var list: some View {
        ScrollView {
            VStack(spacing: 10) {
                ForEach(store.sorted) { item in
                    row(item)
                }
            }
            .padding(16)
        }
    }

    private func row(_ item: BucketListItem) -> some View {
        HStack(spacing: 12) {
            Button { store.toggle(id: item.id) } label: {
                Image(systemName: item.done ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24))
                    .foregroundStyle(item.done ? Color.louvCoral : Color.gray.opacity(0.4))
            }
            .buttonStyle(.plain)

            Text(item.emoji).font(.system(size: 22))

            Text(item.title)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(item.done ? Color.gray : Color.deepRose)
                .strikethrough(item.done, color: .gray)

            Spacer(minLength: 8)

            Button { store.remove(id: item.id) } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.gray.opacity(0.5))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 14))
        .louvShadow()
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Text("🪣").font(.system(size: 48))
            Text("Your shared wishlist")
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(Color.deepRose)
            Text("Add date ideas you both want to try — they sync to each other, and you can tick them off as you go.")
                .font(.system(size: 14))
                .foregroundStyle(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 44)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Actions

    private func addItem() {
        // addedBy is filled server-side with the signed-in uid on write; the local
        // entry passes nil (it's informational and not shown in v1).
        store.add(title: newTitle, emoji: selectedEmoji, addedBy: nil)
        newTitle = ""
        fieldFocused = false
    }
}
