//
//  Secrets.swift
//  AIPanelSchedules
//
//  Created by Kenneth Riendeau on 12/7/25.
//

import Foundation

enum Secrets {
    static var geminiAPIKey: String {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "GEMINI_API_KEY") as? String else {
            fatalError("❌ GEMINI_API_KEY missing from Info.plist or Build Settings")
        }
        return key
    }
}
