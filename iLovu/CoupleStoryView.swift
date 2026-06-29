// CoupleStoryView.swift
// The optional "couple story" editor. Relationship status is chosen first; the
// relevant MILESTONE date fields then reveal below it and update live as status
// changes — a Dating couple never sees engagement/wedding fields. Plus each
// partner's own birthday (the partner's is read-only).
//
// Rules honored here:
//   • status-conditional reveal (dating / engaged / wedding)
//   • the `dating` date ALWAYS drives Days Together; engagement + wedding are
//     additional cherished dates, never the counter source
//   • every field optional/skippable, all editable later
//   • changing status HIDES now-irrelevant milestones but never deletes them —
//     drafts stay loaded, and Save only writes the currently-visible ones
//
// Everything is couple-level and rides the existing couple-doc writes + live
// listener, so the partner sees changes automatically.

import SwiftUI

struct CoupleStoryView: View {

    @Environment(CoupleService.self) private var couples
    @Environment(\.dismiss) private var dismiss

    // Working copies — committed only on Save. nil/absent = "not set yet".
    @State private var status: String?
    @State private var milestoneDrafts: [CoupleMilestone: Date] = [:]
    @State private var birthday: Date?
    @State private var isSaving = false

    private let statuses = ["Dating", "Engaged", "Married"]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.blushCream.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        // Status first — it decides which milestone dates are
                        // relevant — then the conditional milestones below it.
                        statusSection
                        milestonesSection
                        birthdaySection
                        partnerBirthdaySection
                    }
                    .padding(20)
                    // Every card here is a fixed-light Color.white surface, so pin
                    // the content to the light color scheme. Otherwise default-
                    // colored elements (notably the compact DatePicker date values)
                    // fall back to .primary and render WHITE in dark mode —
                    // invisible on the white card until tapped. Same class of bug
                    // 198edf8 fixed for the text fields; DatePickers were missed.
                    .environment(\.colorScheme, .light)
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
            status = couples.relationshipStatus
            birthday = couples.myBirthday
            // Load ALL milestone drafts regardless of status, so toggling status
            // away and back restores previously-entered dates (hide, don't lose).
            for milestone in CoupleMilestone.allCases {
                if let date = couples.milestoneDate(milestone) {
                    milestoneDrafts[milestone] = date
                }
            }
        }
    }

    // MARK: - Status

    private var statusSection: some View {
        storyCard {
            sectionTitle("Where are you two? 💞")
            HStack(spacing: 8) {
                ForEach(statuses, id: \.self) { option in
                    statusPill(option)
                }
            }
        }
    }

    // MARK: - Milestones (conditional on status)

    @ViewBuilder
    private var milestonesSection: some View {
        let visible = Self.visibleMilestones(for: status)
        if visible.isEmpty {
            storyCard {
                sectionTitle("Your dates")
                Text("Choose where you're at above and we'll ask for the dates that matter. 💕")
                    .font(.system(size: 13))
                    .foregroundStyle(.gray)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } else {
            ForEach(visible, id: \.self) { milestone in
                milestoneCard(milestone)
            }
        }
    }

    private func milestoneCard(_ milestone: CoupleMilestone) -> some View {
        storyCard {
            sectionTitle(label(for: milestone))

            if milestoneDrafts[milestone] == nil {
                addButton(addTitle(for: milestone)) { milestoneDrafts[milestone] = Date() }
            } else {
                datePicker(milestoneBinding(milestone))
                // Only the dating date powers the counter — preview it inline.
                if milestone == .dating, let days = previewDays(milestoneDrafts[milestone]) {
                    Text("\(days.formatted()) days together")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.louvCoral)
                }
            }
        }
    }

    // MARK: - Birthdays

    private var birthdaySection: some View {
        storyCard {
            sectionTitle("Your birthday 🎂")
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
            sectionTitle("\(partner)'s birthday 🎂")
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

    // MARK: - Milestone copy + reveal rules

    // Which milestones are relevant for a given status. Dating couples never see
    // engagement/wedding; status nil shows none (pick a status first).
    private static func visibleMilestones(for status: String?) -> [CoupleMilestone] {
        switch status {
        case "Dating":  return [.dating]
        case "Engaged": return [.dating, .engaged]
        case "Married": return [.dating, .engaged, .wedding]
        default:        return []
        }
    }

    // The dating prompt reads differently for a Dating couple ("first met") than
    // for one that's since engaged/married ("started dating").
    private func label(for milestone: CoupleMilestone) -> String {
        switch milestone {
        case .dating:
            return status == "Dating"
                ? "When did you first meet / start dating? 💕"
                : "When did you start dating? 💕"
        case .engaged: return "When did you get engaged? 💍"
        case .wedding: return "Your wedding day 💒"
        }
    }

    private func addTitle(for milestone: CoupleMilestone) -> String {
        switch milestone {
        case .dating:  return "Add the date"
        case .engaged: return "Add engagement date"
        case .wedding: return "Add wedding date"
        }
    }

    // MARK: - Pieces

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 17, weight: .bold))
            .foregroundStyle(Color.deepRose)
            .fixedSize(horizontal: false, vertical: true)
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
    // Milestones + birthdays are all past dates, so the future is disallowed.
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

    private func milestoneBinding(_ milestone: CoupleMilestone) -> Binding<Date?> {
        Binding(get: { milestoneDrafts[milestone] },
                set: { milestoneDrafts[milestone] = $0 })
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

    // Live preview of the counter while the dating picker is open.
    private func previewDays(_ date: Date?) -> Int? {
        guard let date else { return nil }
        let cal = Calendar.current
        let elapsed = cal.dateComponents([.day],
                                         from: cal.startOfDay(for: date),
                                         to: cal.startOfDay(for: Date())).day ?? 0
        return max(1, elapsed + 1)
    }

    // MARK: - Save

    // Writes status, the currently-VISIBLE milestones that changed (hidden ones
    // are left untouched in Firestore — hide, don't delete), and the birthday.
    private func save() async {
        isSaving = true

        if let status, status != couples.relationshipStatus {
            await couples.setRelationshipStatus(status)
        }
        for milestone in Self.visibleMilestones(for: status) {
            if let date = milestoneDrafts[milestone], date != couples.milestoneDate(milestone) {
                await couples.setMilestone(milestone, date: date)
            }
        }
        if let birthday, birthday != couples.myBirthday {
            await couples.setBirthday(birthday)
        }

        isSaving = false
        dismiss()
    }
}
