//
//  CreditsService.swift
//  AIPanelSchedules
//
//  Created by Kenneth Riendeau on 12/19/25.
//

import FirebaseAuth
import FirebaseFirestore
import Combine

@MainActor
class CreditsService: ObservableObject {

    @Published var credits: Int = 0

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    func startListening() {
        guard let uid = Auth.auth().currentUser?.uid else { return }

        let userRef = db.collection("users").document(uid)

        listener = userRef.addSnapshotListener { snap, _ in
            if let credits = snap?.data()?["credits"] as? Int {
                self.credits = credits
                print("🪙 Credits updated:", credits)
            }
        }
    }
    func consumeCredit() {
        guard let uid = Auth.auth().currentUser?.uid else {
            print("❌ No user — cannot consume credit")
            return
        }

        guard credits > 0 else {
            print("❌ Tried to consume credit but balance is 0")
            return
        }

        let userRef = db.collection("users").document(uid)

        // Optimistic UI update (feels instant)
        credits -= 1

        userRef.updateData([
            "credits": FieldValue.increment(Int64(-1))
        ]) { error in
            if let error = error {
                print("❌ Failed to consume credit:", error.localizedDescription)
            } else {
                print("✅ Credit consumed successfully")
            }
        }
    }
    func grantCredits(_ amount: Int) {
        guard let uid = Auth.auth().currentUser?.uid else { return }

        let userRef = db.collection("users").document(uid)

        print("🪙 Granting credits:", amount)

        userRef.updateData([
            "credits": FieldValue.increment(Int64(amount))
        ]) { error in
            if let error = error {
                print("❌ Failed to grant credits:", error.localizedDescription)
            } else {
                print("✅ Credits granted:", amount)
            }
        }
    }

    deinit {
        listener?.remove()
    }
}
