//
//  SettingsOnboardingListView.swift
//  AIPanelSchedules
//
//  Created by Kenneth Riendeau on 12/20/25.
//
import SwiftUI

struct SettingsOnboardingListView: View {
    var body: some View {
        List {
            NavigationLink("Welcome") {
                OnboardingIntroView()
            }

            NavigationLink("How It Works") {
                OnboardingScanExplanationView()
            }

            NavigationLink("Supported PDF Format") {
                OnboardingPDFWarningView()
            }

            NavigationLink("Credits") {
                OnboardingCreditsView()
            }
        }
        .navigationTitle("Onboarding")
    }
}
