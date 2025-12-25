//
//  ProjectsListView.swift
//  AIPanelSchedules
//
//  Created by Kenneth Riendeau on 12/7/25.
//

import SwiftUI

import SwiftUI
import FirebaseAuth

enum AppTab: Int {
    case projects = 0
    case credits = 1
    case settings = 2
}
struct ProjectsListView: View {

    @EnvironmentObject var projectService: ProjectService
    @EnvironmentObject var auth: AuthService
    @State private var selectedTab: AppTab = .projects
    @State private var showingNewProjectSheet = false
    @State private var newProjectName = ""

            CreditsView()
                .tabItem {
                    Label("Credits", systemImage: "creditcard")
                }
                .tag(AppTab.credits)
            SettingsView()
                   .tabItem {
                       Label("Settings", systemImage: "gearshape")
                   }
                   .tag(AppTab.settings)
        }
        .onAppear {
            projectService.loadProjects()
        }
        .sheet(isPresented: $showingNewProjectSheet) {
            NewProjectSheet(
                projectName: $newProjectName,
                onSave: {
                    projectService.createProject(name: newProjectName)
                    projectService.loadProjects()
                    newProjectName = ""
                }
            )
        }
    }

    // MARK: Greeting
    private var greetingText: String {
        if let name = auth.user?.displayName, !name.isEmpty {
            return "Welcome back, \(name)"
        }
        if let email = auth.user?.email {
            return "Welcome back"
        }
        return "Your Projects"
    }
    private func createNewProject() {
        projectService.createProject(name: "Untitled Project")
        projectService.loadProjects()
    }
    @ViewBuilder
    private var projectsContent: some View {
        VStack(spacing: 0) {

            // MARK: Header
            VStack(alignment: .leading, spacing: 6) {
                Text(greetingText)
                    .font(.largeTitle)
                    .bold()

                Text("Your panel schedule projects")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()

            // MARK: Project List
            List {
                ForEach(projectService.projects) { project in
                    NavigationLink(
                        destination: ProjectDetailViewV2(projectId: project.id, selectedTab: $selectedTab
                    )
                  )  {
                        ProjectCard(project: project)
                    }
                    .listRowInsets(EdgeInsets())
                    .padding(.vertical, 6)
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        let project = projectService.projects[index]
                        projectService.deleteProject(project)
                    }
                }
            }
            .listStyle(.plain)

            // MARK: Footer Actions
            VStack(spacing: 12) {
                Button {
                    showingNewProjectSheet = true
                } label: {
                    Label("New Project", systemImage: "plus")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.borderedProminent)
                if showDebugPush {
                    Button("🔔 Debug Test Push") {
                        Task {
                            await sendDebugTestPush()
                        }
                    }
                    .buttonStyle(.bordered)
                    .tint(.orange)
                }
                .buttonStyle(.bordered)
#if DEBUG
                Button("🔔 Debug Test Push") {
                    Task {
                        await sendDebugTestPush()
                .font(.footnote)
            .padding()
                .buttonStyle(.bordered)
                .tint(.orange)
#endif
        guard let uid = auth.user?.uid else {
            print("❌ No UID — cannot send test push")
            return
        }

        let urlString =
        "https://us-central1-aipanelschedules.cloudfunctions.net/testPush?uid=\(uid)"

        guard let url = URL(string: urlString) else {
            print("❌ Invalid test push URL")
            return
        }

        do {
            let (_, response) = try await URLSession.shared.data(from: url)
            print("✅ Test push request sent:", response)
        } catch {
            print("❌ Test push request failed:", error.localizedDescription)
        }
    }
}

   



struct ProjectCard: View {
    let project: Project

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text(project.name)
                    .font(.headline)
                    .foregroundColor(.primary)

                Text("\(project.pdfFiles.count) Panel Schedule Drawings uploaded")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(14)
    }
}
