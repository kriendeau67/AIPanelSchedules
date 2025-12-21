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

                // MARK: Support
                Section("Support") {
                    Button("Contact Developer") {
                        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
                        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
                        let device = UIDevice.current.model
                        let systemVersion = UIDevice.current.systemVersion

                        let subject = "PanelScanner Support"
                        let body = """
                        App Version: \(appVersion) (\(buildNumber))
                        Device: \(device)
                        iOS: \(systemVersion)

                        Please describe the issue below:
                        """

                        let email = "mailto:kriendeau67@gmail.com?subject=\(subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&body=\(body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"

                        if let url = URL(string: email) {
                            UIApplication.shared.open(url)
                        }
                    }
                }

                // MARK: About
                Section("About") {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("About the Developer")
                            .font(.headline)

                        Text("PanelScanner is built by an 40 year commercial electrical foreman who is passionate about electrical work and data. The app is focused on turning real-world field drawings into clean, usable data — without overcomplicating the workflow.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
                        Text("Version \(version)")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
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
