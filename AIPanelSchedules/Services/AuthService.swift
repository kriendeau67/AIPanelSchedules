//
//  AuthService.swift
//  AIPanelSchedules
//
//  Created by Kenneth Riendeau on 12/7/25.
//

import Foundation
import FirebaseAuth
import GoogleSignIn
import GoogleSignInSwift
import AuthenticationServices
import CryptoKit
import Combine
import FirebaseCore
import FirebaseMessaging
import FirebaseFirestore
@MainActor
class AuthService: ObservableObject {

    @Published var user: User? = Auth.auth().currentUser
    @Published var needsReAuth = false
    private var nonce: String?

    init() {
        Auth.auth().addStateDidChangeListener { _, user in
            self.user = user
            
            if user == nil {
                // 🚨 ONE STEP: Tell the app to wipe all cached data!
                print("🧹 User is nil, broadcasting clear command...")
                NotificationCenter.default.post(name: NSNotification.Name("UserDidLogout"), object: nil)
            } else {
                print("👤 User detected, syncing FCM token...")
               
                  //  (UIApplication.shared.delegate as? AppDelegate)?.saveTokenToFirestore(nil)
                    Task { await self.forceRefreshAndSaveFcmToken() }
                
            }
        }
    }

    // MARK: - Google Sign In
    func signInWithGoogle(presenting viewController: UIViewController) async throws {
        guard let clientID = FirebaseApp.app()?.options.clientID else { return }

        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config

        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: viewController)
        guard let idToken = result.user.idToken else { return }

        let credential = GoogleAuthProvider.credential(withIDToken: idToken.tokenString,
                                                       accessToken: result.user.accessToken.tokenString)

        try await Auth.auth().signIn(with: credential)
        //(UIApplication.shared.delegate as? AppDelegate)?.saveTokenToFirestore(nil)
        Task { await self.forceRefreshAndSaveFcmToken() }
    }

    // MARK: - Apple Sign In Helpers
    func startSignInWithAppleFlow() -> ASAuthorizationAppleIDRequest {
        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]

        let nonce = randomNonceString()
        self.nonce = nonce
        request.nonce = sha256(nonce)

        return request
    }

    func handleAppleCompletion(_ result: Result<ASAuthorization, Error>) async throws {
        guard case let .success(authResults) = result,
              let credential = authResults.credential as? ASAuthorizationAppleIDCredential
        else { return }

        guard let nonce = nonce else { return }
        guard let appleIDToken = credential.identityToken else { return }

        let idTokenString = String(decoding: appleIDToken, as: UTF8.self)

        let firebaseCredential = OAuthProvider.appleCredential(
            withIDToken: idTokenString,
            rawNonce: nonce,
            fullName: credential.fullName
        )
        try await Auth.auth().signIn(with: firebaseCredential)
        //(UIApplication.shared.delegate as? AppDelegate)?.saveTokenToFirestore(nil)
        Task { await self.forceRefreshAndSaveFcmToken() }
    }
    func deleteAccount() async {
        guard let user = Auth.auth().currentUser else {
            print("❌ No user found in Auth.auth().currentUser")
            return
        }
        
        print("🚀 Attempting to delete user: \(user.uid)")
        
        do {
            // 1. Delete from Firebase Server
            try await user.delete()
            print("✅ Firebase Auth user deleted successfully")
            
            // 2. 🔥 ADD THIS: Force the local session to clear
            // This stops the "Delete twice" bug
            try Auth.auth().signOut()
            
            // 3. Clear the published property
            self.user = nil
            
        } catch let error as NSError {
            print("❌ DELETE ERROR CODE: \(error.code)")
            print("❌ DELETE ERROR MESSAGE: \(error.localizedDescription)")
            
            if error.code == AuthErrorCode.requiresRecentLogin.rawValue {
                print("⚠️ Triggering needsReAuth flag")
                self.needsReAuth = true
            }
        }
    }
    
    func forceRefreshAndSaveFcmToken() async {
        guard let uid = Auth.auth().currentUser?.uid else {
            print("⚠️ No UID, cannot refresh FCM token")
            return
        }

        do {
            let token = try await Messaging.messaging().token()
            print("🆕 Fresh FCM token fetched:", token)

            try await Firestore.firestore()
                .collection("users")
                .document(uid)
                .setData([
                    "fcmToken": token,
                    "fcmUpdatedAt": FieldValue.serverTimestamp()
                ], merge: true)

            print("✅ Fresh FCM token saved for UID:", uid)
        } catch {
            print("❌ Failed to fetch/save FCM token:", error.localizedDescription)
        }
    }
    // MARK: - Utilities for Apple Sign In
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashed = SHA256.hash(data: inputData)
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }

    private func randomNonceString(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length

        while remainingLength > 0 {
            let randoms = (0 ..< 16).map { _ in UInt8.random(in: 0 ... 255) }

            randoms.forEach { random in
                if remainingLength == 0 { return }
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }
        return result
    }

    func signOut() throws {
        try Auth.auth().signOut()
        self.user = nil
    }
}
