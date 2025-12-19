//
//  AppDelegate.swift
//  AIPanelSchedules
//
//  Created by Kenneth Riendeau on 12/15/25.
//

import UIKit
import Firebase
import FirebaseMessaging
import UserNotifications
import FirebaseAuth

import UIKit
import Firebase
import FirebaseMessaging
import FirebaseAuth
import FirebaseFirestore
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {

        FirebaseApp.configure()

        UNUserNotificationCenter.current().delegate = self

        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .badge, .sound]
        ) { granted, _ in
            print("🔔 Push permission granted:", granted)
        }

        application.registerForRemoteNotifications()

        Messaging.messaging().delegate = self

        // 🔥 CLEAR BADGE ON APP LAUNCH
            application.applicationIconBadgeNumber = 0

        return true
    }
    func application(
            _ application: UIApplication,
            didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
        ) {
            Messaging.messaging().apnsToken = deviceToken
        }


    // ✅ MUST be here (class-level)
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        return [.banner, .sound]
    }

    // 🔔 Foreground presentation
        

        // 🔕 User tapped notification → clear badge
        func userNotificationCenter(
            _ center: UNUserNotificationCenter,
            didReceive response: UNNotificationResponse
        ) async {
            UIApplication.shared.applicationIconBadgeNumber = 0
        }
}



extension AppDelegate: MessagingDelegate {
    func messaging(
        _ messaging: Messaging,
        didReceiveRegistrationToken fcmToken: String?
    ) {
        guard let token = fcmToken,
              let uid = Auth.auth().currentUser?.uid
        else { return }

     //   print("📲 FCM TOKEN:", token)

        Firestore.firestore()
            .collection("users")
            .document(uid)
            .setData([
                "fcmToken": token
            ], merge: true)
    }
}
