// WouldYouRatherService.swift
// Firestore sync for the "Would You Rather" couple game — the game twin of
// DailyQuestionService. One doc per day:
//   couples/{coupleId}/games/{dateKey}  -> promptIndex, choices: { uid -> "A"|"B" }
//
// Same "answer to unlock" reveal as the Daily Question: each partner writes ONLY
// their own uid key in `choices` (deep merge), and the reveal (did we match?)
// unlocks once BOTH choices are present — pure client logic on the synced doc.
// The games firestore.rules block enforces the own-key-only write, mirroring
// dailyAnswers. Owned at the app root and injected via the environment.

import Foundation
import FirebaseAuth
import FirebaseFirestore

// The Firestore-side shape of one day's round. uid-keyed `choices` map, same
// per-partner shape as dailyAnswers' `answers`.
struct GameRoundDoc: Codable, Identifiable {

    /// == the doc id (the local-date key). Populated on read, nil on write.
    @DocumentID var id: String?

    /// Which prompt this round was — snapshotted so a past day resolves correctly
    /// even if the bank is later reordered.
    var promptIndex: Int
    /// uid -> "A" | "B". Both present => the reveal unlocks for both partners.
    var choices: [String: String]
    @ServerTimestamp var updatedAt: Timestamp?
}

@MainActor
@Observable
final class WouldYouRatherService {

    private var db: Firestore { Firestore.firestore() }

    // MARK: - Write (record MY choice for the day)

    /// Writes the signed-in user's A/B choice to couples/{coupleId}/games/{dateKey}.
    /// setData(merge:true) deep-merges the `choices` map — sets only my uid key and
    /// preserves the partner's, exactly what the games update rule allows.
    func saveChoice(coupleId: String, dateKey: String, promptIndex: Int, choice: String) async {
        guard let uid = Auth.auth().currentUser?.uid else {
            log("saveChoice skipped — not signed in")
            return
        }
        let ref = db.collection("couples").document(coupleId)
            .collection("games").document(dateKey)
        do {
            try await ref.setData([
                "promptIndex": promptIndex,
                "choices":     [uid: choice],          // deep-merged: sets only MY key
                "updatedAt":   FieldValue.serverTimestamp()
            ], merge: true)
            log("saved choice \(dateKey) \(choice) for \(uid)")
        } catch {
            log("ERROR saveChoice \(dateKey): \(error.localizedDescription)")
        }
    }

    // MARK: - Observe (today's round -> mine + partner)

    /// Listens to the games/{dateKey} doc and delivers the resolved (mine, partner)
    /// choices — partner being the one `choices` key that isn't the signed-in uid.
    /// Fires on attach and on every change (the partner choosing lands live). The
    /// caller owns the registration and must `.remove()` it.
    func observeToday(
        coupleId: String,
        dateKey: String,
        onChange: @escaping (_ mine: String?, _ partner: String?) -> Void
    ) -> ListenerRegistration {
        let ref = db.collection("couples").document(coupleId)
            .collection("games").document(dateKey)
        let myUid = Auth.auth().currentUser?.uid

        return ref.addSnapshotListener { [weak self] snapshot, error in
            if let error {
                self?.log("games listener error: \(error.localizedDescription)")
                return
            }
            guard let snapshot, snapshot.exists,
                  let doc = try? snapshot.data(as: GameRoundDoc.self) else {
                onChange(nil, nil)
                return
            }
            let mine = myUid.flatMap { doc.choices[$0] }
            let partner = doc.choices.first { $0.key != myUid }?.value
            self?.log("delivered \(dateKey) — mine:\(mine ?? "-") partner:\(partner ?? "-")")
            onChange(mine, partner)
        }
    }

    private func log(_ message: String) {
        #if DEBUG
        print("🎲 WouldYouRatherService: \(message)")
        #endif
    }
}
