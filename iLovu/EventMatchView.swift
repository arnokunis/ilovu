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

    // Inline "more about this place" reveal on the card. Toggled by BOTH the
    // "View Details" button and tapping the place name — no navigation, no
    // external app; the extra venue info (rating, description, address) expands
    // on the MiniEventCard itself.
    @State private var showInfo = false

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

                MiniEventCard(event: event, isExpanded: $showInfo)

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

            // Tertiary: View Details — reveals the extra venue info INLINE on the
            // card (rating / description / address); no navigation, stays on the
            // celebration. Tapping the place name does the same thing.
            Button {
                withAnimation(LouvAnimation.spring) { showInfo.toggle() }
            } label: {
                Text(showInfo ? "Hide Details" : "View Details")
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

    // Drives the inline info reveal. Toggled by the place name (below) and by the
    // "View Details" button in EventMatchView — shared state, same gesture.
    @Binding var isExpanded: Bool

    var body: some View {
        VStack(spacing: 10) {
            Text(event.emoji)
                .font(.system(size: 48))

            Text(event.title)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Color.deepRose)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
                // Tapping the place name reveals the inline info — same action as
                // the View Details button. contentShape makes the whole label tappable.
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(LouvAnimation.spring) { isExpanded.toggle() }
                }

            Text("\(event.venue) · \(event.date)")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.gray)
                .multilineTextAlignment(.center)

            HStack(spacing: 6) {
                pill(text: event.category.rawValue, background: .louvCoral)
                pill(text: event.price,             background: .louvOrange)
            }

            if isExpanded {
                inlineInfo
                    .transition(.opacity.combined(with: .move(edge: .top)))
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

    // The inline "more about this place" reveal: rating, description, address.
    // All three come straight off the LocalEvent the card already has (Tier 1 —
    // no extra fetching). Each row is hidden when its field is empty/nil.
    @ViewBuilder
    private var inlineInfo: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider().padding(.vertical, 2)

            if let ratingLine {
                HStack(spacing: 5) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.louvOrange)
                    Text(ratingLine)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.deepRose)
                }
            }

            if !event.description.isEmpty {
                Text(event.description)
                    .font(.system(size: 13))
                    .foregroundStyle(.gray)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let address = event.address, !address.isEmpty {
                HStack(alignment: .top, spacing: 5) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.louvCoral)
                    Text(address)
                        .font(.system(size: 12))
                        .foregroundStyle(.gray)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .multilineTextAlignment(.leading)
    }

    // "4.5 · 320 ratings" (count omitted if absent); nil when the venue is unrated.
    private var ratingLine: String? {
        guard let rating = event.rating else { return nil }
        let r = String(format: "%.1f", rating)
        guard let count = event.reviewCount else { return r }
        return "\(r) · \(count) ratings"
    }
}

#Preview {
    EventMatchView(event: SampleEvents.all[0])
}
