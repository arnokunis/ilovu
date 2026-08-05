// DailyQuestionService.swift
// All Firestore reads/writes for the shared Daily Question live here, so
// DailyQuestionCard answers/reveals through intent-named methods and never
// touches Firestore directly. Owned at the app root (iLovuApp) and injected via
// the environment, same as MatchService / MissionService.
//
//   couples/{coupleId}/dailyAnswers/{dateKey}   -> one doc per calendar day
//     dateKey, question (snapshot), answers: { uid -> text }, updatedAt
//
// The doc id IS the local-date key ("2026-06-25"), so both partners' apps
// converge on the same document for a given day — exactly like missions keyed by
// cardId. Each member writes ONLY their own entry in the `answers` map (a deep
// merge, so it never clobbers the partner's answer), which is what the
// dailyAnswers firestore.rules block enforces (a member may only add their own
// uid key — the map twin of the swipes "add only yourself" rule).
//
// THE REVEAL ("answer to unlock") is pure client logic on the synced doc: the
// card shows the partner's answer only once BOTH answers are present — mirroring
// how MatchService treats both uids appearing in likedBy as a match.
//
// Failures are SILENT to callers (same fallback spirit as MissionService) but
// printed under #if DEBUG while build-testing.

import Foundation
import FirebaseAuth
import FirebaseFirestore

// The Firestore-side shape of one day's answers. uid-keyed `answers` map, same
// per-partner shape as Couple.displayNames / birthdays.
struct DailyAnswerDoc: Codable, Identifiable {

    /// == the doc id (the local-date key "YYYY-MM-DD"). Populated on read, nil on write.
    @DocumentID var id: String?

    var dateKey: String
    /// The question text as asked that day — snapshotted so a past day still
    /// shows the right prompt even if the question bank is later edited.
    var question: String
    /// uid -> answer text. Both present => the reveal unlocks for both partners.
    var answers: [String: String]
    @ServerTimestamp var updatedAt: Timestamp?
}

@MainActor
@Observable
final class DailyQuestionService {

    // Computed so constructing the service touches no Firebase — safe to
    // default-init at the app root and in previews, same as the other services.
    private var db: Firestore { Firestore.firestore() }

    // MARK: - Write (record MY answer for the day)

    /// Writes the signed-in user's answer for `dateKey` to
    /// couples/{coupleId}/dailyAnswers/{dateKey}. setData(merge:true) with a
    /// nested `answers` map DEEP-MERGES — it sets only my uid key and preserves
    /// the partner's, which is exactly what the dailyAnswers update rule allows
    /// (the only changed answers key may be my own). Create + update are the same
    /// call (the first answerer creates the doc, the second merges in).
    func saveAnswer(coupleId: String, dateKey: String, question: String, answer: String) async {
        guard let uid = Auth.auth().currentUser?.uid else {
            log("saveAnswer skipped — not signed in")
            return
        }
        let trimmed = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let ref = db.collection("couples").document(coupleId)
            .collection("dailyAnswers").document(dateKey)

        do {
            try await ref.setData([
                "dateKey":   dateKey,
                "question":  question,
                "answers":   [uid: trimmed],            // deep-merged: sets only MY key
                "updatedAt": FieldValue.serverTimestamp()
            ], merge: true)
            AppAnalytics.log("daily_question_answered")
            log("saved answer \(dateKey) for \(uid)")
        } catch {
            log("ERROR saveAnswer \(dateKey): \(error.localizedDescription)")
        }
    }

    // MARK: - Observe (today's doc -> mine + partner)

    /// Listens to the single dailyAnswers/{dateKey} doc and delivers the resolved
    /// (mine, partner) answers — partner being the one `answers` key that isn't
    /// the signed-in uid, so the card never needs the partner's uid. Fires on
    /// attach (initial state) and on every change (the partner answering lands
    /// live). The caller owns the registration and must `.remove()` it.
    func observeToday(
        coupleId: String,
        dateKey: String,
        onChange: @escaping (_ mine: String?, _ partner: String?) -> Void
    ) -> ListenerRegistration {
        let ref = db.collection("couples").document(coupleId)
            .collection("dailyAnswers").document(dateKey)
        let myUid = Auth.auth().currentUser?.uid

        return ref.addSnapshotListener { [weak self] snapshot, error in
            if let error {
                self?.log("dailyAnswers listener error: \(error.localizedDescription)")
                return
            }
            // No doc yet (nobody's answered today) => both nil => answering state.
            guard let snapshot, snapshot.exists,
                  let doc = try? snapshot.data(as: DailyAnswerDoc.self) else {
                onChange(nil, nil)
                return
            }
            let answers = doc.answers
            let mine = myUid.flatMap { answers[$0] }
            let partner = answers.first { $0.key != myUid }?.value
            self?.log("delivered \(dateKey) — mine:\(mine != nil) partner:\(partner != nil)")
            onChange(mine, partner)
        }
    }

    // MARK: - Debug logging

    private func log(_ message: String) {
        #if DEBUG
        print("💬 DailyQuestionService: \(message)")
        #endif
    }
}
