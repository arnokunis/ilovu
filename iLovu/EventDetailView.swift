// EventDetailView.swift
// The rich "decide together" screen shown when a couple taps an
// event card (or chooses View Details from the match celebration).
// Premium feeling on purpose — this is where "maybe?" turns into
// "yes, let's go here".
//
// On appear the view fires a Places API search for the event's
// title + venue. If a match comes back, the screen swaps to show
// real photos, real rating, real reviews, real hours, real address.
// If anything goes wrong — no key, no network, no match — the
// sample data we already had stays on screen with no error UI.
// The user just sees a perfectly normal detail view either way.

import SwiftUI
import EventKit

struct EventDetailView: View {

    let event: LocalEvent

    // When false, the bottom action bar omits "Add to Calendar" — used by the
    // venue-mission sheet (Route A), where the mission already owns its date and
    // its own calendar add, so a guessed-time calendar action doesn't fit. The
    // Near You deck→detail path keeps the default (true), unchanged.
    var showCalendarAction: Bool = true

    @Environment(\.dismiss) private var dismiss

    @State private var calendarFeedback: CalendarFeedback = .idle

    // Real Google Places data merged onto the sample event. Nil until
    // (and unless) the fetch succeeds. `displayEvent` below picks the
    // right one to render.
    @State private var enrichedEvent: LocalEvent?

    // Owned per-view because EventDetailView is the only thing that
    // currently uses location. Permission is requested lazily on
    // .task, and the LocationManager falls back to London so the
    // initial fetch can run even before the user answers the prompt.
    @State private var locationManager = LocationManager()

    /// What the body renders. Enriched if we got real data, original
    /// sample event otherwise — so any failure mode is invisible.
    private var displayEvent: LocalEvent {
        enrichedEvent ?? event
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    photoGallery
                    titleBlock
                    addressAndHoursRow
                    descriptionBlock
                    highlightsSection
                    reviewsSection
                }
                .padding(.bottom, 24)
            }
            // .safeAreaInset pins the action bar to the bottom AND
            // automatically reserves space in the scroll content so
            // the last review card isn't hidden behind it.
            .safeAreaInset(edge: .bottom) {
                actionBar
            }

            closeButton
                .padding(.top, 12)
                .padding(.trailing, 16)
        }
        .background(Color.blushCream.ignoresSafeArea())
        // .task starts when the view appears and gets cancelled
        // automatically when it disappears. Perfect lifecycle hook
        // for a one-shot fetch like this.
        .task {
            locationManager.requestPermissionIfNeeded()
            await loadPlaceData()
        }
    }

    // MARK: - Photo gallery
    // Real Google photos when we have them, otherwise our deterministic gradient
    // placeholders. Rendered via PlaceholderPhoto -> BundledRemoteImage (NOT
    // AsyncImage): the Places key is iOS-bundle-restricted, so the request must
    // send the X-Ios-Bundle-Identifier header or Google 403s the photo.

    private var photoGallery: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(0..<photoCount, id: \.self) { index in
                    PlaceholderPhoto(
                        emoji: displayEvent.emoji,
                        index: index,
                        photoString: photoString(at: index)
                    )
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.top, 16)
    }

    private var photoCount: Int {
        displayEvent.photos.isEmpty ? 4 : displayEvent.photos.count
    }

    private func photoString(at index: Int) -> String? {
        guard index < displayEvent.photos.count else { return nil }
        return displayEvent.photos[index]
    }

    // MARK: - Title block

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(displayEvent.title)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Color.deepRose)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                pill(text: displayEvent.category.rawValue, background: .louvCoral)
                pill(text: displayEvent.price,             background: .louvOrange)
            }

            if let rating = displayEvent.rating, let reviewCount = displayEvent.reviewCount {
                HStack(spacing: 6) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 14))
                    Text(String(format: "%.1f", rating))
                        .font(.system(size: 15, weight: .semibold))
                    Text("·")
                        .foregroundStyle(.gray)
                    Text("\(reviewCount.formatted()) reviews")
                        .font(.system(size: 14))
                        .foregroundStyle(.gray)
                }
                .foregroundStyle(Color.louvCoral)
            }
        }
        .padding(.horizontal, 20)
    }

    private func pill(text: String, background: Color) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(background)
            .clipShape(Capsule())
    }

    // MARK: - Address & hours

    @ViewBuilder
    private var addressAndHoursRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let hours = displayEvent.openingHours {
                infoRow(icon: "clock", text: hours)
            }
            if let address = displayEvent.address {
                infoRow(icon: "mappin.and.ellipse", text: address)
            }
            // Always show the date/venue line — universal "when + where".
            infoRow(icon: "calendar", text: "\(displayEvent.date) · \(displayEvent.venue)")
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .louvShadow()
        .padding(.horizontal, 20)
    }

    private func infoRow(icon: String, text: String) -> some View {
        // Top-aligned so the icon sits beside the FIRST line when the text wraps
        // to multiple lines (e.g. the full weekly hours block).
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.louvCoral)
                .frame(width: 18)
            Text(text)
                .font(.system(size: 14))
                .foregroundStyle(Color.deepRose)
                .multilineTextAlignment(.leading)
            Spacer()
        }
    }

    // MARK: - Description

    private var descriptionBlock: some View {
        Text(displayEvent.description)
            .font(.system(size: 15))
            .foregroundStyle(.gray)
            .lineSpacing(3)
            .padding(.horizontal, 20)
    }

    // MARK: - Highlights

    @ViewBuilder
    private var highlightsSection: some View {
        if !displayEvent.highlights.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                sectionLabel("Highlights")
                    .padding(.horizontal, 20)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(displayEvent.highlights, id: \.self) { highlight in
                            Text(highlight)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Color.deepRose)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(Color.white)
                                .clipShape(Capsule())
                                .louvShadow()
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 4)
                }
            }
        }
    }

    // MARK: - Reviews

    @ViewBuilder
    private var reviewsSection: some View {
        if !displayEvent.reviewSnippets.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                sectionLabel("What people say")
                    .padding(.horizontal, 20)

                VStack(spacing: 10) {
                    ForEach(displayEvent.reviewSnippets) { snippet in
                        ReviewCard(snippet: snippet)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    // MARK: - Action bar

    private var actionBar: some View {
        HStack(spacing: 12) {
            Button(action: openBooking) {
                Text("Book Now →")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(LouvGradient.coral)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)

            if showCalendarAction {
                Button {
                    Task { await addToCalendar() }
                } label: {
                    Image(systemName: calendarIcon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(calendarTint)
                        .frame(width: 52, height: 52)
                        .background(Color.white)
                        .clipShape(Circle())
                        .overlay(
                            Circle().stroke(calendarTint.opacity(0.45), lineWidth: 1.5)
                        )
                }
                .buttonStyle(.plain)
                .disabled(calendarFeedback == .added)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 12)
        .background(Color.white)
        .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: -4)
    }

    private var calendarIcon: String {
        calendarFeedback == .added ? "checkmark" : "calendar.badge.plus"
    }
    private var calendarTint: Color {
        calendarFeedback == .added ? Color.matchGreen : Color.louvCoral
    }

    // MARK: - Close button

    private var closeButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 30))
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, .black.opacity(0.4))
        }
    }

    // MARK: - Book Now

    private func openBooking() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        // One place builds the link: a real Ticketmaster ticket page (affiliate-
        // wrapped once the Impact id is configured — today it isn't, so it opens
        // plain), else any other bookingURL, else a Google search. See
        // EventLinkBuilder.
        if let url = EventLinkBuilder.ticketURL(for: displayEvent) {
            UIApplication.shared.open(url)
        }
    }

    // MARK: - Add to Calendar

    private func addToCalendar() async {
        let store = EKEventStore()
        do {
            let granted = try await store.requestWriteOnlyAccessToEvents()
            guard granted else {
                setFeedback(.denied); return
            }

            let ekEvent = EKEvent(eventStore: store)
            ekEvent.title    = "iLovu: \(displayEvent.title)"
            ekEvent.notes    = "\(displayEvent.venue) — \(displayEvent.date)\n\n\(displayEvent.description)"
            ekEvent.location = displayEvent.address ?? displayEvent.venue
            // Real events carry their actual start instant; sample events fall
            // back to tomorrow-evening so the calendar entry still has a slot.
            let start = displayEvent.startDate ?? Self.defaultDate()
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

    // MARK: - Places fetch
    // Fires on view appear via .task. Goes through VenueCache, NOT
    // PlacesService directly: the first lookup of a given query+area
    // pays one billed Text Search and writes it to Firestore; repeats
    // are free cache reads (stale entries refresh in the background).
    // Uses the ORIGINAL event's title + venue as the query — not
    // displayEvent — because a successful enrichment changes
    // displayEvent's venue and we don't want re-fetches chasing it.
    // The view's contract is unchanged: it still gets back an enriched
    // LocalEvent, or silently keeps the sample data on any miss/failure.

    private func loadPlaceData() async {
        let places = PlacesService()
        let cache = VenueCache()

        // A places-deck card (cardId == placeId) already has its venue in the
        // cache from the deck resolve — read it directly, a FREE cache read with
        // no billed call. Events / sample cards resolve by their title+venue text.
        let cached: CachedVenue?
        if event.sourceDeck == .places {
            cached = await cache.venue(forId: event.cardId)
        } else {
            let query = "\(event.title) \(event.venue)"
            let bias  = (latitude:  locationManager.coordinate.latitude,
                         longitude: locationManager.coordinate.longitude)
            cached = await cache.venue(forQuery: query, locationBias: bias)
        }

        // nil = cache miss AND no live match (or no API key, or offline).
        // Same silent-fallback contract as before — sample data stays.
        guard let cached else { return }

        // Pass the service so enrichment can rebuild photo URLs from the cached
        // key-free photoNames with the CURRENT API key (no key in stored docs).
        let enriched = LocalEvent.enriching(event, with: cached, using: places)
        await MainActor.run {
            withAnimation(.easeInOut(duration: 0.3)) {
                self.enrichedEvent = enriched
            }
        }
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

// MARK: - CalendarFeedback

private enum CalendarFeedback {
    case idle, added, denied, error
}

// MARK: - LocalEvent enrichment
// Merges a CachedVenue (Google Places data — from the Firestore cache
// or a fresh search, the caller can't tell) into a sample LocalEvent.
// The strategy: keep our curated values for fields where we have
// stronger editorial content (title, description, highlights), and
// adopt Google's where ground truth wins (rating, reviews, address,
// hours, photos, booking link). Falls back to the original any time
// the cached field is empty.

extension LocalEvent {
    static func enriching(
        _ original: LocalEvent,
        with cached: CachedVenue,
        using service: PlacesService
    ) -> LocalEvent {

        // Up to 4 photo URLs, rebuilt fresh from the cached key-free photoNames
        // with the current API key — so a rotated key works without re-caching.
        let photoURLs: [String] = cached.photoURLStrings(using: service)

        // Up to 3 brand-safe review snippets: 4★+ ONLY (we never surface a 1–3★
        // rant in an anti-pressure product), THEN take the top 3. Filtering on the
        // raw rating (>= 4.0) before rounding means a 3.5 — which would round up to
        // a 4-star display — is still excluded. compactMap also drops any review
        // missing a field we need to render.
        let snippets: [ReviewSnippet] = Array(
            cached.reviews.compactMap { review -> ReviewSnippet? in
                guard
                    let text   = review.text,
                    let author = review.authorName,
                    let rating = review.rating,
                    rating >= 4
                else { return nil }
                // Google returns rating as a Double 1.0-5.0; our model is Int 1-5.
                // .rounded() before Int conversion avoids a 4.9 losing a star.
                return ReviewSnippet(author: author, rating: Int(rating.rounded()), text: text)
            }
            .prefix(3)
        )

        // The full weekly hours, one day per line. The cache deliberately does
        // NOT store the volatile "open now" flag (it would be wrong the moment
        // it's a few hours old), so we show the static weekly schedule only —
        // never "Open now". nil/empty stays nil so the row hides.
        let hours: String? = {
            guard let week = cached.openingHoursWeekday, !week.isEmpty else { return nil }
            return week.joined(separator: "\n")
        }()

        return LocalEvent(
            id:             original.id,
            cardId:         original.cardId,   // preserve the match key across enrichment
            title:          original.title,
            venue:          cached.displayName.isEmpty ? original.venue : cached.displayName,
            date:           original.date,
            price:          original.price,
            category:       original.category,
            emoji:          original.emoji,
            description:    original.description,
            rating:         cached.rating          ?? original.rating,
            reviewCount:    cached.userRatingCount  ?? original.reviewCount,
            address:        cached.formattedAddress ?? original.address,
            openingHours:   hours                   ?? original.openingHours,
            photos:         photoURLs.isEmpty ? original.photos        : photoURLs,
            highlights:     original.highlights,
            reviewSnippets: snippets.isEmpty  ? original.reviewSnippets : snippets,
            bookingURL:     cached.googleMapsUri    ?? original.bookingURL,
            // Carry the real-event fields THROUGH enrichment — without this, a
            // venue-enriched Ticketmaster event would lose its ticket link
            // (affiliate base) and start time. Venue enrichment only adds the
            // Maps URI as a non-Ticketmaster bookingURL fallback; the affiliate-
            // eligible ticketURLBase stays intact so EventLinkBuilder prefers it.
            startDate:      original.startDate,
            ticketURLBase:  original.ticketURLBase,
            sourceDeck:     original.sourceDeck
        )
    }
}

// MARK: - PlaceholderPhoto
// Renders one tile in the photo gallery. If we were handed a
// Google Places photo URL, fetches it asynchronously. Otherwise
// (or while loading, or on failure) renders the deterministic
// gradient + emoji placeholder.
private struct PlaceholderPhoto: View {
    let emoji: String
    let index: Int
    let photoString: String?

    private static let palettes: [(Color, Color)] = [
        (.louvCoral,  .louvOrange),
        (.deepRose,   .louvCoral),
        (Color(red: 188/255, green: 143/255, blue: 211/255), .deepRose),
        (.louvOrange, Color(red: 255/255, green: 214/255, blue: 153/255)),
        (.louvCoral,  Color(red: 248/255, green: 200/255, blue: 220/255))
    ]

    private var gradient: LinearGradient {
        let pair = Self.palettes[index % Self.palettes.count]
        return LinearGradient(
            colors: [pair.0, pair.1],
            startPoint: .topLeading,
            endPoint:   .bottomTrailing
        )
    }

    var body: some View {
        Group {
            if let urlString = photoString, urlString.hasPrefix("http") {
                // URLSession + X-Ios-Bundle-Identifier header (via BundledRemoteImage)
                // instead of AsyncImage — Google Places photo URLs are blocked by
                // our iOS-bundle-restricted key unless the bundle header is sent,
                // which AsyncImage can't do. Keeps the key restriction locked down.
                BundledRemoteImage(urlString: urlString) {
                    placeholder
                }
            } else {
                placeholder
            }
        }
        .frame(width: 280, height: 200)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var placeholder: some View {
        ZStack {
            gradient
            Text(emoji)
                .font(.system(size: 64))
                .shadow(color: .black.opacity(0.15), radius: 6, y: 3)
        }
    }
}

// MARK: - ReviewCard

private struct ReviewCard: View {
    let snippet: LocalEvent.ReviewSnippet

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(snippet.author)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.deepRose)
                Spacer()
                HStack(spacing: 2) {
                    ForEach(0..<snippet.rating, id: \.self) { _ in
                        Image(systemName: "star.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.louvCoral)
                    }
                }
            }

            Text("\u{201C}\(snippet.text)\u{201D}")
                .font(.system(size: 14))
                .italic()
                .foregroundStyle(.gray)
                .lineSpacing(2)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .louvShadow()
    }
}

#Preview {
    EventDetailView(event: SampleEvents.all[0])
}
