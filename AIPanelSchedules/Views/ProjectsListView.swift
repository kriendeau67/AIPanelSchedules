//
//  ProjectsListView.swift
//  AIPanelSchedules
//
//  Created by Kenneth Riendeau on 12/7/25.
//

import SwiftUI

import SwiftUI
import FirebaseAuth

struct ProjectsListView: View {

    @EnvironmentObject var projectService: ProjectService
    @EnvironmentObject var auth: AuthService

    @State private var showingNewProjectSheet = false
    @State private var newProjectName = ""

    var body: some View {
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
                        destination: ProjectDetailViewV2(projectId: project.id)
                    ) {
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

                Button("Sign Out") {
                    try? auth.signOut()
                }
                .font(.footnote)
                .foregroundColor(.secondary)
            }
            .padding()
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
