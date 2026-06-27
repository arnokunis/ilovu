// MissionDetailView.swift
// The planning screen for a single Mission. Shown as a sheet either
// straight after the Match celebration ("Plan This Date") or from
// the upcoming-missions list on the Home dashboard.
//
// Five sections, top to bottom:
//   • Header card: emoji, title, description, difficulty pill
//   • Schedule: a DatePicker that sets the optional scheduledDate
//   • Budget: a free-text TextField
//   • Checklist: tappable rows for the three steps
//   • Actions: "Add to Calendar" (EventKit) and "Mark Complete ✓"
//
// All mutations write back to the shared MissionStore via .onChange.

import SwiftUI
import EventKit

struct MissionDetailView: View {

    // Shared stores — we pull these from the environment instead of
    // owning them locally, so any update here is instantly visible to
    // HomeView, UsView, MainTabView, etc.
    @Environment(MissionStore.self) private var missionStore
    @Environment(MemoryStore.self)  private var memoryStore

    // Couple link + paywall gate. Saving a memory can complete condition A of
    // the gate (2nd match + 1st memory); we feed the new count here so the wall
    // arms — it still won't present until the next calm mission-start in Home.
    @Environment(CoupleService.self) private var coupleService
    @Environment(PaywallGate.self)   private var paywallGate

    // SwiftUI's built-in dismiss action. Works because we're presented
    // as a sheet by the parent.
    @Environment(\.dismiss) private var dismiss

    // The home-screen Spark Score. Marking a mission complete bumps it.
    @AppStorage("sparkScore") private var sparkScore: Int = 2

    // Local editable copy of the mission. We mutate this in-memory and
    // mirror changes back to the store via .onChange — that keeps the
    // store the single source of truth without needing a Binding here.
    @State private var mission: Mission

    // Feedback strip under the calendar button. Resets on each retry.
    @State private var calendarFeedback: CalendarFeedback = .idle

    // Drives the "save a memory of this date" sheet that opens when
    // the user taps Mark Complete.
    @State private var showCompletionSheet: Bool = false

    // Completion alert state — shown after the memory sheet closes
    // (whether they saved a memory or skipped it).
    @State private var showCompletionAlert: Bool = false

    init(mission: Mission) {
        _mission = State(initialValue: mission)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    headerCard
                    scheduleCard
                    budgetCard
                    checklistCard
                    calendarButton
                    completeButton
                }
                .padding(20)
            }
            .background(Color.blushCream.ignoresSafeArea())
            .navigationTitle("Your Mission")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color.louvCoral)
                }
            }
            // Every time the local copy changes, sync it back to the
            // store. Mission is Equatable so SwiftUI dedupes no-op writes.
            .onChange(of: mission) { _, newValue in
                missionStore.update(newValue)
            }
            // First step of the complete flow: collect a photo/rating/note
            // (or skip). The sheet hands a Memory? back to handleCompletion,
            // which then commits the mission state + spark bump.
            .sheet(isPresented: $showCompletionSheet) {
                CompleteMissionSheet(mission: mission) { memory in
                    handleCompletion(memory: memory)
                }
            }
            .alert("Mission complete! 🎉", isPresented: $showCompletionAlert) {
                Button("Awesome") { dismiss() }
            } message: {
                Text("Your spark grew 🔥")
            }
        }
    }

    // MARK: - Header

    private var headerCard: some View {
        VStack(spacing: 14) {
            Text(mission.card.emoji)
                .font(.system(size: 64))

            Text(mission.card.title)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(Color.deepRose)
                .multilineTextAlignment(.center)

            Text(mission.card.description)
                .font(.system(size: 15))
                .foregroundStyle(.gray)
                .multilineTextAlignment(.center)

            Text(mission.card.difficulty.rawValue)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(Color.louvCoral)
                .clipShape(Capsule())
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .louvShadow()
    }

    // MARK: - Schedule

    // SwiftUI DatePicker takes a non-optional Binding<Date>. We wrap
    // the optional scheduledDate with a Binding that substitutes a
    // sensible default when the underlying value is nil, and writes
    // the user's pick back through.
    private var scheduleBinding: Binding<Date> {
        Binding(
            get: { mission.scheduledDate ?? Self.defaultScheduledDate() },
            set: { mission.scheduledDate = $0 }
        )
    }

    // Default suggestion when no date is set yet: tomorrow at 7pm.
    private static func defaultScheduledDate() -> Date {
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        return calendar.date(bySettingHour: 19, minute: 0, second: 0, of: tomorrow) ?? tomorrow
    }

    private var scheduleCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Planned For")
            DatePicker(
                "",
                selection: scheduleBinding,
                displayedComponents: [.date, .hourAndMinute]
            )
            .labelsHidden()
            .tint(Color.louvCoral)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .louvShadow()
    }

    // MARK: - Budget

    // Optional<String> doesn't play nicely with TextField's String
    // binding, so we wrap it the same way as the date.
    private var budgetBinding: Binding<String> {
        Binding(
            get: { mission.budget ?? "" },
            set: { mission.budget = $0.isEmpty ? nil : $0 }
        )
    }

    private var budgetCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Budget")
            TextField("e.g. €30 or No spend", text: budgetBinding)
                .textFieldStyle(.plain)
                .font(.system(size: 16))
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

    // MARK: - Checklist

    private var checklistCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionLabel("Checklist")

            // Index-based loop because we need a mutable handle to
            // each item to toggle `done` in place inside @State.
            ForEach(mission.checklist.indices, id: \.self) { index in
                checklistRow(index: index)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .louvShadow()
    }

    private func checklistRow(index: Int) -> some View {
        let item = mission.checklist[index]
        return Button {
            withAnimation(LouvAnimation.spring) {
                mission.checklist[index].done.toggle()
                UISelectionFeedbackGenerator().selectionChanged()
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: item.done ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, item.done ? Color.matchGreen : Color.gray.opacity(0.5))

                Text(item.title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(item.done ? .gray : Color.deepRose)
                    .strikethrough(item.done, color: .gray)

                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Add to Calendar

    private var calendarButton: some View {
        VStack(spacing: 10) {
            Button {
                Task { await addToCalendar() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Add to Calendar")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundStyle(Color.louvCoral)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.white)
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(Color.louvCoral.opacity(0.45), lineWidth: 1.5)
                )
                .louvShadow()
            }
            .buttonStyle(.plain)

            calendarFeedbackLabel
        }
    }

    // Below the calendar button, a small status pill that appears
    // briefly to confirm or explain what happened.
    @ViewBuilder
    private var calendarFeedbackLabel: some View {
        switch calendarFeedback {
        case .idle:
            EmptyView()
        case .added:
            feedback(text: "Added to your calendar", color: .matchGreen, icon: "checkmark.circle.fill")
        case .denied:
            feedback(text: "Calendar access denied — enable it in Settings", color: .gray, icon: "info.circle.fill")
        case .error:
            feedback(text: "Couldn't add the event", color: .passRed, icon: "exclamationmark.circle.fill")
        }
    }

    private func feedback(text: String, color: Color, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 13))
            Text(text).font(.system(size: 13, weight: .medium))
        }
        .foregroundStyle(color)
        .transition(.opacity)
    }

    private func addToCalendar() async {
        let store = EKEventStore()
        #if DEBUG
        print("📅 Calendar: tapped — '\(mission.card.title)'; authStatus=\(EKEventStore.authorizationStatus(for: .event).rawValue) (0=notDetermined 2=denied 3=fullAccess 4=writeOnly)")
        #endif
        do {
            // iOS 17+ split calendar permission into read-only and
            // write-only. We only need to add events, so we ask for
            // the narrower scope. Requires NSCalendarsWriteOnlyAccessUsageDescription
            // in Info — without it, this call crashes.
            let granted = try await store.requestWriteOnlyAccessToEvents()
            #if DEBUG
            print("📅 Calendar: write-only access granted=\(granted)")
            #endif
            guard granted else {
                setFeedback(.denied)
                return
            }

            let event = EKEvent(eventStore: store)
            event.title = "iLovu Date: \(mission.card.title)"
            event.notes = mission.card.description
            let start = mission.scheduledDate ?? Self.defaultScheduledDate()
            event.startDate = start
            event.endDate = start.addingTimeInterval(2 * 60 * 60)  // 2-hour default block
            let target = store.defaultCalendarForNewEvents
            event.calendar = target
            #if DEBUG
            // The smoking gun: WHICH calendar/account the event is written to.
            // sourceType 0=Local 1=Exchange 2=CalDAV(Google/iCloud) 3=MobileMe 4=Subscribed 5=Birthdays.
            // A Google account shows source title = the Google email; iCloud shows "iCloud".
            if let cal = target {
                print("📅 Calendar: target='\(cal.title)' account='\(cal.source.title)' sourceType=\(cal.source.sourceType.rawValue) modifiable=\(cal.allowsContentModifications)")
            } else {
                print("📅 Calendar: defaultCalendarForNewEvents is NIL — write-only may not expose a default; save will throw")
            }
            #endif

            try store.save(event, span: .thisEvent)
            #if DEBUG
            print("📅 Calendar: save SUCCEEDED — id=\(event.eventIdentifier ?? "nil") on '\(event.calendar?.title ?? "?")' account='\(event.calendar?.source.title ?? "?")' start=\(start)")
            #endif
            // Also record on the mission so the home row shows the date.
            if mission.scheduledDate == nil { mission.scheduledDate = start }
            setFeedback(.added)
        } catch {
            #if DEBUG
            print("📅 Calendar: save FAILED — \(error)")
            #endif
            setFeedback(.error)
        }
    }

    @MainActor
    private func setFeedback(_ value: CalendarFeedback) {
        withAnimation(.easeOut(duration: 0.2)) {
            calendarFeedback = value
        }
    }

    // MARK: - Mark Complete

    private var completeButton: some View {
        Button(action: markComplete) {
            Text("Mark Complete ✓")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(LouvGradient.coral)
                .clipShape(Capsule())
                .louvShadow()
        }
        .buttonStyle(.plain)
        .disabled(mission.status == .completed)
        .opacity(mission.status == .completed ? 0.5 : 1)
    }

    // Tapping Mark Complete no longer completes immediately — it
    // opens the memory-capture sheet first. The actual mission state
    // change happens in handleCompletion below, once the sheet closes.
    private func markComplete() {
        showCompletionSheet = true
    }

    // Called by CompleteMissionSheet when the user finishes. Memory
    // is non-nil if they picked a photo, nil if they tapped Skip.
    // Either way the mission completes and the spark bumps — the
    // memory is a bonus, not a requirement.
    private func handleCompletion(memory: Memory?) {
        if let memory {
            memoryStore.add(memory)
            // Memory saved → update the gate's memory count (arms condition A
            // when the couple has also reached its 2nd match). Never presents
            // here — the wall waits for the next calm mission-start.
            if let coupleId = coupleService.coupleId {
                paywallGate.recordMemoryCount(memoryStore.memories.count, coupleId: coupleId)
            }
        }

        UINotificationFeedbackGenerator().notificationOccurred(.success)
        mission.status = .completed

        // Spark goes up by one, capped at 5. min() makes the cap explicit
        // so the UI can't end up rendering six lit flames.
        sparkScore = min(sparkScore + 1, 5)

        // Tiny delay so the alert doesn't try to present while the
        // completion sheet is still mid-dismiss — SwiftUI doesn't
        // like stacked modal transitions.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            showCompletionAlert = true
        }
    }

    // MARK: - Shared helpers

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.gray)
            .textCase(.uppercase)
            .tracking(0.5)
    }
}

// MARK: - CalendarFeedback
// The three outcomes of trying to add to the calendar, plus an idle
// starting state. Kept as a tiny enum at file scope (private) so the
// view body can switch on it cleanly.
private enum CalendarFeedback {
    case idle, added, denied, error
}

#Preview {
    MissionDetailView(mission: Mission(from: SampleCards.all[0]))
        .environment(MissionStore())
        .environment(MemoryStore())
}
