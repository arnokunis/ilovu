// CoupleStoryView.swift
// The optional "couple story" editor: anniversary (couple-level), relationship
// stage (couple-level), and your own birthday (per-partner). The partner's
// birthday is shown read-only — they set their own. Everything is optional and
// editable any time (no enter-once-or-lose), and all of it rides the existing
// couple-doc writes + live listener so the partner sees changes automatically.
//
// Presented as a sheet from the Us tab (permanent "Your story" row) and from the
// post-connect "set up your story" card.

import SwiftUI

struct CoupleStoryView: View {

    @Environment(CoupleService.self) private var couples
    @Environment(\.dismiss) private var dismiss

    // Working copies — committed only on Save. nil = "not set yet".
    @State private var anniversary: Date?
    @State private var birthday: Date?
    @State private var status: String?
    @State private var isSaving = false

    private let statuses = ["Dating", "Engaged", "Married"]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.blushCream.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        anniversarySection
                        statusSection
                        birthdaySection
                        partnerBirthdaySection
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Your Story")
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
            anniversary = couples.anniversaryDate
            birthday = couples.myBirthday
            status = couples.relationshipStatus
        }
    }

    // MARK: - Sections

    private var anniversarySection: some View {
        storyCard {
            sectionTitle("Together since 💕")
            Text("We'll count your days together from this date.")
                .font(.system(size: 13))
                .foregroundStyle(.gray)

            if anniversary == nil {
                addButton("Add anniversary") { anniversary = Date() }
            } else {
                datePicker($anniversary)
                if let days = previewDays {
                    Text("\(days.formatted()) days together")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.louvCoral)
                }
            }
        }
    }

    private var statusSection: some View {
        storyCard {
            sectionTitle("Relationship")
            HStack(spacing: 8) {
                ForEach(statuses, id: \.self) { option in
                    statusPill(option)
                }
            }
        }
    }

    private var birthdaySection: some View {
        storyCard {
            sectionTitle("Your birthday")
            if birthday == nil {
                addButton("Add your birthday") { birthday = Date() }
            } else {
                datePicker($birthday)
            }
        }
    }

    @ViewBuilder
    private var partnerBirthdaySection: some View {
        storyCard {
            let partner = couples.partnerDisplayName ?? "Your partner"
            sectionTitle("\(partner)'s birthday")
            if let date = couples.partnerBirthday {
                Text(date.formatted(date: .long, time: .omitted))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.deepRose)
            } else {
                Text("\(partner) hasn't added theirs yet.")
                    .font(.system(size: 13))
                    .foregroundStyle(.gray)
            }
        }
    }

    // MARK: - Pieces

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 17, weight: .bold))
            .foregroundStyle(Color.deepRose)
    }

    private func storyCard<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10, content: content)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .louvShadow()
    }

    // A DatePicker over an optional date — bound through a non-optional proxy.
    // Dates can't be in the future (anniversary / birthday are both past dates).
    private func datePicker(_ source: Binding<Date?>) -> some View {
        DatePicker(
            "",
            selection: Binding(get: { source.wrappedValue ?? Date() },
                               set: { source.wrappedValue = $0 }),
            in: ...Date(),
            displayedComponents: .date
        )
        .labelsHidden()
        .datePickerStyle(.compact)
        .tint(Color.louvCoral)
    }

    private func addButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "plus.circle.fill")
                Text(title).font(.system(size: 15, weight: .semibold))
            }
            .foregroundStyle(Color.louvCoral)
        }
        .buttonStyle(.plain)
    }

    private func statusPill(_ option: String) -> some View {
        let selected = status == option
        return Button {
            status = option
        } label: {
            Text(option)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(selected ? .white : .gray)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background {
                    if selected { LouvGradient.coral } else { Color.blushCream }
                }
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // Live preview of the counter while the picker is open.
    private var previewDays: Int? {
        guard let anniversary else { return nil }
        let cal = Calendar.current
        let elapsed = cal.dateComponents([.day],
                                         from: cal.startOfDay(for: anniversary),
                                         to: cal.startOfDay(for: Date())).day ?? 0
        return max(1, elapsed + 1)
    }

    // MARK: - Save

    // Writes only the fields the user actually set/changed. Each rides its own
    // dot-path couple-doc update via CoupleService.
    private func save() async {
        isSaving = true
        if let anniversary, anniversary != couples.anniversaryDate {
            await couples.setAnniversaryDate(anniversary)
        }
        if let birthday, birthday != couples.myBirthday {
            await couples.setBirthday(birthday)
        }
        if let status, status != couples.relationshipStatus {
            await couples.setRelationshipStatus(status)
        }
        isSaving = false
        dismiss()
    }
}
