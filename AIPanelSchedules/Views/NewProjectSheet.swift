//
//  NewProjectSheet.swift
//  AIPanelSchedules
//
//  Created by Kenneth Riendeau on 12/7/25.
//
import SwiftUI

struct NewProjectSheet: View {

    @Binding var projectName: String
    var onSave: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Project Name")) {
                    TextField("Enter project name", text: $projectName)
                }
            }
            .navigationTitle("New Project")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if !projectName.isEmpty {
                            onSave()
                            dismiss()
                        }
                    }
                }
            }
        }
    }
}
