//
//  LoginView.swift
//  AIPanelSchedules
//
//  Created by Kenneth Riendeau on 12/7/25.
//

import SwiftUI
import GoogleSignInSwift
import AuthenticationServices
import Combine

struct LoginView: View {

    @EnvironmentObject var auth: AuthService
    @State private var appleRequest: ASAuthorizationAppleIDRequest?
    
    var body: some View {
        VStack(spacing: 20) {

            Text("AIPanelSchedules")
                .font(.largeTitle)
                .bold()
                .padding(.bottom, 40)

            // Google Button
            GoogleSignInButton {
                signInWithGoogle()
            }
            .frame(width: 250, height: 50)

            // Apple Button
            SignInWithAppleButton(.signIn, onRequest: { request in
                self.appleRequest = auth.startSignInWithAppleFlow()
                if let appleRequest = self.appleRequest {
                    request.requestedScopes = appleRequest.requestedScopes
                    request.nonce = appleRequest.nonce
                }
            }, onCompletion: { result in
                Task {
                    try? await auth.handleAppleCompletion(result)
                }
            })
            .signInWithAppleButtonStyle(.black)
            .frame(width: 250, height: 50)

        }
        .padding()
    }

    // Helper for Google Sign In
    private func signInWithGoogle() {
        guard let rootVC = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first?.keyWindow?.rootViewController else { return }

        Task {
            try? await auth.signInWithGoogle(presenting: rootVC)
        }
    }
}
