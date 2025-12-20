import SwiftUI
import StoreKit

struct SettingsView: View {

    @EnvironmentObject var creditsService: CreditsService
    @EnvironmentObject var auth: AuthService

    var body: some View {
        NavigationStack {
            List {

                // MARK: Account
                Section("Account") {
                    HStack {
                        Text("Credits Available")
                        Spacer()
                        Text("\(creditsService.credits)")
                            .bold()
                    }

                    Button("Restore Purchases") {
                        Task {
                            do {
                                print("🔄 Restore: starting AppStore.sync()")
                                try await AppStore.sync()
                                print("✅ Restore: AppStore.sync() finished")
                            } catch {
                                print("❌ Restore failed:", error.localizedDescription)
                            }
                        }
                    }
                }

                // MARK: App
                Section("App") {
                    NavigationLink("View Onboarding") {
                        SettingsOnboardingListView()
                    }
                }

                // MARK: About
                Section("About") {
                    Text("Version 1.0")
                        .foregroundColor(.secondary)
                }

                // MARK: Sign Out
                Section {
                    Button("Sign Out", role: .destructive) {
                        try? auth.signOut()
                    }
                }
            }
            .navigationTitle("Settings")
        }
        .onAppear {
            creditsService.startListening()
        }
    }
}
