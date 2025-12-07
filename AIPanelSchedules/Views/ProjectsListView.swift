//
//  ProjectsListView.swift
//  AIPanelSchedules
//
//  Created by Kenneth Riendeau on 12/7/25.
//

import SwiftUI

struct ProjectsListView: View {

   // @State private var projects: [Project] = []
    @EnvironmentObject var projectService: ProjectService
    @EnvironmentObject var auth: AuthService
    @State private var showingNewProjectSheet = false
    @State private var newProjectName = ""
    
    var body: some View {
        VStack {
            HStack {
                Text("Your Projects")
                    .font(.largeTitle)
                    .bold()
                Spacer()

                Button("Sign Out") {
                    try? auth.signOut()
                }
            }
            .padding()

            List {
                ForEach(projectService.projects) { project in
                    NavigationLink(destination: ProjectDetailView(projectId: project.id)) {
                        Text(project.name)
                    }
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        let project = projectService.projects[index]
                        projectService.deleteProject(project)
                    }
                }
            }

            Button(action: {
                showingNewProjectSheet = true
            }) {
                Text("New Project")
                    .font(.headline)
                    .padding()
            }
            .buttonStyle(.borderedProminent)
            .padding()
        }
        .onAppear {
            projectService.loadProjects()   // <-- CORRECT LOCATION
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

    private func createNewProject() {
        projectService.createProject(name: "Untitled Project")
        projectService.loadProjects()
    }
}
