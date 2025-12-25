        import SwiftUI
        import Firebase

       
        @main
        struct AIPanelSchedulesApp: App {
            
            @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
            @StateObject var auth = AuthService()
            @StateObject var projectService = ProjectService()
            @StateObject private var creditsService = CreditsService()
            @StateObject private var storeKitService = StoreKitService()
            @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

            var body: some Scene {
                WindowGroup {

                    NavigationStack {
                        if !hasCompletedOnboarding {
                            OnboardingContainerView()
                        } else if auth.user == nil {
                            LoginView()
                        } else {
                            ProjectsListView()
                        }
                    }
                    // 👇 ENVIRONMENT OBJECTS MUST BE HERE (outside the if/else)
                    .environmentObject(auth)
                    .environmentObject(projectService)
                    .environmentObject(creditsService)
                    .environmentObject(storeKitService)
                    .onAppear {
                        creditsService.startListening()
                    }
                    .onChange(of: storeKitService.purchaseEvent) { oldEvent, newEvent in
                                            if let event = newEvent {
                                                let amount = storeKitService.creditsForProductID(event.productID)
                                                print("🛒 App-level purchase detected: \(event.productID), granting \(amount) credits")
                                                creditsService.grantCredits(amount)
                                                
                                                // Clear it so it only happens once
                                                storeKitService.purchaseEvent = nil
                                            }
                                        }
                }
            }
        }
