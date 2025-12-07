        import SwiftUI
        import Firebase

        class AppDelegate: NSObject, UIApplicationDelegate {
            func application(_ application: UIApplication,
                             didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
                
                FirebaseApp.configure()

                return true
            }
        }
        @main
        struct AIPanelSchedulesApp: App {
            
            @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
            @StateObject var auth = AuthService()
            @StateObject var projectService = ProjectService()
            
            var body: some Scene {
                WindowGroup {
                    NavigationStack {
                        if auth.user == nil {
                            LoginView()
                        } else {
                            ProjectsListView()
                        }
                    }
                    // 👇 ENVIRONMENT OBJECTS MUST BE HERE (outside the if/else)
                    .environmentObject(auth)
                    .environmentObject(projectService)
                }
            }
        }
