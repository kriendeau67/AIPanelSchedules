//
//  OnboardingContainerView.swift
//  AIPanelSchedules
//
//  Created by Kenneth Riendeau on 12/20/25.
//

import SwiftUI

struct OnboardingContainerView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    @State private var currentPage = 0

    private let totalPages = 4

    var body: some View {
        VStack {
            TabView(selection: $currentPage) {

                OnboardingPageWrapper {
                    OnboardingIntroView()
                }
                .tag(0)

                OnboardingPageWrapper {
                    OnboardingScanExplanationView()
                }
                .tag(1)

                OnboardingPageWrapper {
                    OnboardingPDFWarningView()
                }
                .tag(2)

                OnboardingPageWrapper {
                    OnboardingCreditsView()
                }
                .tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))

            Spacer(minLength: 12)

            // Bottom controls
            HStack {
                if currentPage > 0 {
                    Button("Back") {
                        withAnimation {
                            currentPage -= 1
                        }
                    }
                }

                Spacer()

                Button(currentPage == totalPages - 1 ? "Get Started" : "Next") {
                    withAnimation {
                        if currentPage < totalPages - 1 {
                            currentPage += 1
                        } else {
                            completeOnboarding()
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
    }
   
    private func completeOnboarding() {
        hasCompletedOnboarding = true
    }
}
struct OnboardingScanExplanationView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("How It Works")
                .font(.largeTitle)
                .bold()

            Text("Upload panel schedule PDFs. Scanning is free. Excel files are generated automatically.")
        }
    }
}
struct OnboardingIntroView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Welcome")
                .font(.largeTitle)
                .bold()

            Text("Turn panel schedule PDFs into clean Excel files using AI.")
        }
    }
}

struct OnboardingPDFWarningView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {

            // Title
            Text("Supported PDF Format")
                .font(.largeTitle)
                .bold()

            Text("""
This app is designed specifically for **electrical panel schedule PDFs**.

Uploading other types of drawings may produce incorrect or unusable results.
""")
            .font(.body)

            // Example image
            Image("panel_schedule_example")
                .resizable()
                .scaledToFit()
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.secondary.opacity(0.3))
                )

            // What works
            VStack(alignment: .leading, spacing: 8) {
                Label("Panel schedules with circuit tables", systemImage: "checkmark.circle.fill")
                Label("Multiple panels per page", systemImage: "checkmark.circle.fill")
                Label("Scanned or vector PDFs", systemImage: "checkmark.circle.fill")
            }
            .foregroundColor(.green)
            .font(.subheadline)

            Divider()

            // What doesn't work
            VStack(alignment: .leading, spacing: 8) {
                Label("Floor plans", systemImage: "xmark.circle.fill")
                Label("One-line diagrams", systemImage: "xmark.circle.fill")
                Label("Lighting layouts or risers", systemImage: "xmark.circle.fill")
            }
            .foregroundColor(.red)
            .font(.subheadline)

            // Gentle disclaimer
            Text("""
If you're unsure, you can still try a scan — but results are best when the PDF closely matches the example above.
""")
            .font(.footnote)
            .foregroundColor(.secondary)
        }
    }
}
struct OnboardingCreditsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Credits")
                .font(.largeTitle)
                .bold()

            Text("Credits unlock Excel files. Unlocked files remain available forever.")
        }
    }
}
