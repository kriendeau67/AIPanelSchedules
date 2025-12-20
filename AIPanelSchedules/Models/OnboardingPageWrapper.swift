//
//  OnboardingPageWrapper.swift
//  AIPanelSchedules
//
//  Created by Kenneth Riendeau on 12/20/25.
//
import SwiftUI

struct OnboardingPageWrapper<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                content
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
