import SwiftUI
import StoreKit

struct SettingsView: View {
    
    @EnvironmentObject var creditsService: CreditsService
    @EnvironmentObject var auth: AuthService
    @State private var showingDeleteConfirmation = false
    
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
                    VStack(alignment: .leading, spacing: 8) {
                        
                        Text("About the Developer")
                            .font(.headline)
                        
                        Text("""
                        AIPanelSchedules is built by a commercial electrical foreman with decades of field experience.
                        The app focuses on turning real-world panel schedules into clean, usable data — without
                        overcomplicating the workflow.
                        """)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        
                        Link("Support & Privacy",
                             destination: URL(string: "https://kenriendeaudev.netlify.app/legal.html")!)
                            .font(.subheadline)
                        
                        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
                        Text("Version \(version)")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                
                // MARK: Account Management (Sign Out & Delete)
                Section {
                    Button("Sign Out") {
                        try? auth.signOut()
                    }
                    
                    // 2. The Mandatory Delete Account Button
                    Button("Delete Account", role: .destructive) {
                        showingDeleteConfirmation = true
                    }
                    
                    // NEW: Guidance for the "Recent Login" error
                    if auth.needsReAuth {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Security Verification Required", systemImage: "lock.shield.fill")
                                .font(.caption.bold())
                                .foregroundColor(.red)
                            
                            Text("To protect your data, Apple & Google require a fresh login before deleting an account. Please Sign Out and Sign In again to complete this action.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Button("Sign Out Now") {
                                try? auth.signOut()
                                auth.needsReAuth = false // Reset the flag
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                        .padding(.vertical, 8)
                    }
                }
                .navigationTitle("Settings")
                // 3. Confirmation Dialog
                .confirmationDialog(
                    "Are you sure you want to delete your account?",
                    isPresented: $showingDeleteConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Delete Everything", role: .destructive) {
                        Task {
                            await auth.deleteAccount()
                        }
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This action is permanent. All your credits and scan history will be deleted immediately.")
                }
            }
            .onAppear {
                creditsService.startListening()
            }
        }
    }
}
