// EventMatchView.swift
// The celebration screen when both partners "swipe right" on the
// same local event. Reuses ConfettiLayer and the gradient/heart-pop
// vocabulary from MatchView so the two celebrations feel identical
// — that consistency is the whole point of having Near You feel
// like the same product as Cards.
//
// What's different from MatchView: a MiniEventCard instead of
// MiniMatchedCard, plus an "Add to Calendar" (EventKit) action. "Plan This
// Date" is the shared primary — it adapts the venue into a DateCard and plans
// it as a Mission (date/time + checklist), exactly like a swiped date card.

import SwiftUI
import EventKit

struct EventMatchView: View {

    let event: LocalEvent

    // Called when the user taps "Plan This Date" — hands the parent a fully-built
    // Mission (the venue adapted into a DateCard) to add to the store and open the
    // planning sheet, exactly like MatchView's onPlanThisDate. Defaulted to a no-op
    // so previews still work.
    var onPlanThisDate: (Mission) -> Void = { _ in }

    // Called when the user taps "View Details". MainTabView dismisses
    // the match cover and opens EventDetailView right after. Defaulted
    // to a no-op so previews still work.
    var onViewDetails: () -> Void = {}

    @Environment(\.dismiss) private var dismiss

    @State private var heartScale: CGFloat = 0.3
    @State private var calendarFeedback: CalendarFeedback = .idle

    var body: some View {
        ZStack {
            LouvGradient.coral.ignoresSafeArea()

            ConfettiLayer()

            VStack(spacing: 20) {
                Spacer()

                Text("💖")
                    .font(.system(size: 80))
                    .scaleEffect(heartScale)

                Text("It's a Match! 🎉")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(.white)

                MiniEventCard(event: event)

                Spacer()

                actions
                    .padding(.horizontal, 32)
                    .padding(.bottom, 40)
            }
        }
        .onAppear {
            UINotificationFeedbackGenerator().notificationOccurred(.success)

            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                heartScale = 1.2
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                withAnimation(LouvAnimation.spring) {
                    heartScale = 1.0
                }
            }
        }
    }

    // MARK: - Actions

    private var actions: some View {
        VStack(spacing: 12) {
            // Primary: Plan This Date — the real CTA, mirroring MatchView. Adapts
            // the venue into a DateCard and hands the parent a Mission to plan
            // (date/time + checklist) in MissionDetailView.
            Button {
                onPlanThisDate(Mission(from: DateCard(fromVenue: event)))
                dismiss()
            } label: {
                Text("Plan This Date →")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.louvCoral)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.white)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)

            // Secondary: outline pill, white-on-coral. Adds the event
            // to the iOS Calendar via EventKit. Same permission as
            // MissionDetailView already needs.
            Button {
                Task { await addToCalendar() }
            } label: {
                Text(calendarButtonLabel)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .overlay(
                        Capsule().stroke(Color.white, lineWidth: 2)
                    )
            }
            .buttonStyle(.plain)
            .disabled(calendarFeedback == .added)

            // Tertiary: View Details — call back up to MainTabView so
            // it can dismiss this cover and present EventDetailView.
            Button {
                onViewDetails()
                dismiss()
            } label: {
                Text("View Details")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.plain)

            // Tertiary text button to dismiss back to the deck.
            Button {
                dismiss()
            } label: {
                Text("Keep Swiping")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.vertical, 2)
            }
            .buttonStyle(.plain)
        }
    }

    private var calendarButtonLabel: String {
        switch calendarFeedback {
        case .idle:   return "Add to Calendar"
        case .added:  return "Added to Calendar ✓"
        case .denied: return "Calendar access denied"
        case .error:  return "Couldn't add — try again"
        }
    }

    // MARK: - Add to Calendar

    private func addToCalendar() async {
        let store = EKEventStore()
        do {
            let granted = try await store.requestWriteOnlyAccessToEvents()
            guard granted else {
                setFeedback(.denied)
                return
            }

            let ekEvent = EKEvent(eventStore: store)
            ekEvent.title  = "iLovu: \(event.title)"
            ekEvent.notes  = "\(event.venue) — \(event.date)\n\n\(event.description)"
            ekEvent.location = event.venue

            // We don't parse "Fri 8pm" into a real Date — the user can
            // adjust in the Calendar app. Default to tomorrow at 7pm
            // so it lands somewhere sensible.
            let start = Self.defaultDate()
            ekEvent.startDate = start
            ekEvent.endDate   = start.addingTimeInterval(2 * 60 * 60)
            ekEvent.calendar  = store.defaultCalendarForNewEvents

            try store.save(ekEvent, span: .thisEvent)
            setFeedback(.added)
        } catch {
            setFeedback(.error)
        }
    }

    private static func defaultDate() -> Date {
        let cal = Calendar.current
        let tomorrow = cal.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        return cal.date(bySettingHour: 19, minute: 0, second: 0, of: tomorrow) ?? tomorrow
    }

    @MainActor
    private func setFeedback(_ value: CalendarFeedback) {
        withAnimation(.easeOut(duration: 0.2)) {
            calendarFeedback = value
        }
    }
}

// MARK: - CalendarFeedback
// Mirrors the enum used in MissionDetailView. Kept private to this
// file so each call site can evolve independently.
private enum CalendarFeedback {
    case idle, added, denied, error
}

// MARK: - MiniEventCard
// The tilted "polaroid" version of the event card shown during the
// celebration. Same vibe as MiniMatchedCard inside MatchView.
private struct MiniEventCard: View {
    let event: LocalEvent

    var body: some View {
        VStack(spacing: 10) {
            Text(event.emoji)
                .font(.system(size: 48))

            Text(event.title)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Color.deepRose)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)

            Text("\(event.venue) · \(event.date)")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.gray)
                .multilineTextAlignment(.center)

            HStack(spacing: 6) {
                pill(text: event.category.rawValue, background: .louvCoral)
                pill(text: event.price,             background: .louvOrange)
            }
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 16)
        .frame(width: 250)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.25), radius: 18, x: 0, y: 10)
        .rotationEffect(.degrees(-4))
    }

    private func pill(text: String, background: Color) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(background)
            .clipShape(Capsule())
    }
}

#Preview {
    EventMatchView(event: SampleEvents.all[0])
}
