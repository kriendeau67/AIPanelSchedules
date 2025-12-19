import SwiftUI
import PDFKit
import FirebaseAuth
import FirebaseFirestore
import Combine

// MARK: - Helper Structs
struct PDFSheetItem2: Identifiable {
    let id = UUID()
    let url: URL
}

// MARK: - Main Project View
struct ProjectDetailViewV2: View {
    
    @EnvironmentObject var projectService: ProjectService
    @EnvironmentObject var creditsService: CreditsService
    @State private var showingBuyCreditsAlert = false
    // 1. INPUT: Accept the Project ID (Resolves the ProjectsListView compile error)
    let projectId: String
    
    // 2. PRIMARY DATA: Holds the live project data once fetched.
    @State private var project: Project? = nil
    
    // --- All other @State variables ---
    @State private var currentScanningPDFID: String? = nil
    @State private var showingDocumentPicker = false
    @State private var activePDFSheet: PDFSheetItem2?
    @State private var panels: [Panel] = []
    // The previously used @State private var generatedExcelURL: URL? is now removed,
    // as the PDFFileCard handles persistence logic directly.
    // --- End of other @State variables ---
    
    // MARK: - Custom Initializer (REQUIRED for projectId)
    init(projectId: String) {
        // Initialize the required 'let' property
        self.projectId = projectId
        
        // Initialize all @State properties
        self._project = State(initialValue: nil)
        self._panels = State(initialValue: [])
        self._currentScanningPDFID = State(initialValue: nil)
        self._showingDocumentPicker = State(initialValue: false)
        self._activePDFSheet = State(initialValue: nil)
    }
    
    // MARK: - Data Fetcher (Link Persistence Fix)
    // In ProjectDetailView.swift:
    
    func refreshProjectData() {
        self.projectService.fetchProject(id: self.projectId) { fetchedProject in
            
            Task { @MainActor in
                if let fetchedProject = fetchedProject {
                    
                    // 1. Immediately update the project state with the fresh data.
                    self.project = fetchedProject
                    
                    // 2. Load panels only after the project state is updated.
                    self.loadProjectPanels()
                    
                    // 3. Update the master list only AFTER the local state is fixed.
                    //  self.projectService.loadProjects()
                    
                    print("✅ Project Data Refreshed from Firestore. Link should be visible.")
                } else {
                    print("⚠️ ERROR: Project fetch failed for ID: \(self.projectId)")
                }
            }
        }
    }
    
    func loadProjectPanels() {
        // We ensure panels are loaded only if the project is available.
        guard let project = project else { return }
        projectService.loadPanels(for: project) { loaded in
            DispatchQueue.main.async {
                self.panels = loaded
            }
        }
    }
    private var activePDFs: [PDFFile] {
        project?.pdfFiles.filter { $0.excelUrl == nil } ?? []
    }

    private var finishedPDFs: [PDFFile] {
        project?.pdfFiles.filter { $0.excelUrl != nil } ?? []
    }
    
    var body: some View {
        Group {
            if let project = project {
                List {
                    summarySection(project)
                    documentsSection(project)
                 //   extractedPanelsSection
                }
                .listStyle(.insetGrouped)
                .navigationBarTitleDisplayMode(.inline)
                .sheet(isPresented: $showingDocumentPicker) {
                    DocumentPicker { handlePDFImport(url: $0) }
                }
                .sheet(item: $activePDFSheet) {
                    AsyncPDFViewer(url: $0.url)
                }
                .onAppear(perform: refreshProjectData)
                .onReceive(projectService.$projects) { _ in
                    Task { @MainActor in
                        refreshProjectData()
                    }
                }
            } else {
                ProgressView("Loading Project Data…")
                    .onAppear(perform: refreshProjectData)
            }
        }
    }
    //ViewBuilders
    
    //Summary Secdtion
    @ViewBuilder
    private func summarySection(_ project: Project) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text(project.name)
                    .font(.system(size: 28, weight: .bold, design: .rounded))

                Text("\(project.pdfFiles.count) PDF Files Uploaded")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
        }
    }
    @ViewBuilder
    private func documentsSection(_ project: Project) -> some View {

        Section("PDF Documents") {
            pdfDocumentsSection(project)
        }
        Section("Finished PDFs") {
            finishedPDFsSection
        }
        Section("Excel Files") {
            excelFilesSection(project)
        }
        Section("Extracted Panels") {
            extractedPanelsSection
        }
        Section {
            uploadButton
        }
    }
    // Extract PDF
    @ViewBuilder
    private func pdfDocumentsSection(_ project: Project) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("PDF Documents")
                .font(.headline)
                .padding(.horizontal)

            if project.pdfFiles.isEmpty {
                emptyStateView
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(activePDFs, id: \.id) { file in
                        if let pdfUrl = file.url {
                            
                            PDFFileCard(
                                pdfUrl: pdfUrl,
                                projectId: projectId,
                                pdfId: file.id,
                                panels: panels,
                                fileName: file.fileName,
                                initialExcelUrlString: file.excelUrl,
                                excelLocked: file.excelLocked ?? true,
                                currentScanningID: $currentScanningPDFID,
                                onViewPDF: {
                                    activePDFSheet = PDFSheetItem2(url: pdfUrl)
                                },
                                onDeletePDF: { deletePDF(pdfId: $0) },
                                onScanCompleted: handleScanCompleted,
                                onExcelGenerated: refreshProjectData
                            )
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    //Extracted Panels
    // MARK: - Extracted Panels Summary

    @ViewBuilder
    private var extractedPanelsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Extracted Panels")
                .font(.headline)
                .padding(.horizontal)

            if panels.isEmpty {
                Text("No panels extracted yet")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
            } else {
                NavigationLink {
                    PanelListView(panels: panels)
                } label: {
                    HStack {
                        Image(systemName: "bolt.fill")
                            .foregroundColor(.orange)

                        Text("\(panels.count) panels extracted")
                            .foregroundColor(.primary)

                        Spacer()

                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(8)
                    .padding(.horizontal)
                }
                .buttonStyle(.plain)   // 🔑 THIS LINE IS CRITICAL
            }
        }
    }
    //  Finished PDFS
    @ViewBuilder
    private var finishedPDFsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Finished PDFs")
                .font(.headline)
                .padding(.horizontal)

            if finishedPDFs.isEmpty {
                Text("No finished PDFs yet")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
            } else {
                ForEach(finishedPDFs) { file in
                    Button {
                        if let url = file.url {
                            activePDFSheet = PDFSheetItem2(url: url)
                        }
                    } label: {
                        HStack {
                            Image(systemName: "doc.text")
                                .foregroundColor(.red)

                            Text(file.fileName)
                                .font(.subheadline)
                                .foregroundColor(.primary)

                            Spacer()

                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal)
                }
            }
        }
    }
    //Extract Excel
    @ViewBuilder
    private func excelFilesSection(_ project: Project) -> some View {
        VStack(alignment: .leading, spacing: 12) {

            Text("Excel Files")
                .font(.headline)
                .padding(.horizontal)

            let excelFiles: [ExcelRow] = project.pdfFiles.compactMap { file in
                guard let excel = file.excelUrl,
                      let url = URL(string: excel) else { return nil }

                return ExcelRow(
                    id: file.id,
                    name: file.fileName
                        .replacingOccurrences(of: ".pdf", with: ".xlsx"),
                    url: url,
                    excelLocked: file.excelLocked ?? true   // 🔑 DEFAULT TO LOCKED
                )
            }

            if excelFiles.isEmpty {
                Text("No Excel files generated yet")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
            } else {
                VStack(spacing: 8) {
                    ForEach(excelFiles) { file in
                        HStack {
                            // Checkbox
                            // Unlock / Status badge
                            if file.excelLocked {
                                Button {
                                    // Only unlock if the user has credits
                                    if creditsService.credits > 0 {
                                        print("🪙 Consuming 1 credit to unlock:", file.name)
                                       // creditsService.consumeCredit()
                                      //  projectService.unlockExcel(projectId: project.id, pdfId: file.id)
                                        
                                        projectService.unlockExcelWithCredit(
                                            projectId: project.id,
                                            pdfId: file.id
                                        )
                                        
                                    } else {
                                        print("🛑 No credits available — showing Buy Credits alert")
                                        showingBuyCreditsAlert = true
                                    }
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "lock.fill")
                                        Text("Unlock (1 Credit)")
                                    }
                                    .font(.caption)
                                    .padding(.vertical, 6)
                                    .padding(.horizontal, 10)
                                    .background(Color.red.opacity(0.12))
                                    .foregroundColor(.red)
                                    .cornerRadius(8)
                                }
                                .buttonStyle(.plain)

                    
                                // ✅ UNLOCKED STATE (NON-INTERACTIVE)
                            } else {
                                VStack(alignment: .leading, spacing: 4) {
                                    
                                    // ✅ UNLOCKED BADGE
                                    HStack(spacing: 6) {
                                        Image(systemName: "checkmark.seal.fill")
                                        Text("Unlocked")
                                    }
                                    .font(.caption)
                                    .padding(.vertical, 6)
                                    .padding(.horizontal, 10)
                                    .background(Color.green.opacity(0.15))
                                    .foregroundColor(.green)
                                    .cornerRadius(8)
                                    
                                    // 🔁 DEV ONLY — RELOCK BUTTON
                                    #if DEBUG
                                        Button("🔁 Relock (DEV)") {
                                            projectService.relockExcel(
                                                projectId: project.id,
                                                pdfId: file.id
                                            )
                                        }
                                        .font(.caption2)
                                        .foregroundColor(.orange)
                                    
                                    #endif
                                }
                            }

                            // Excel action
                            Button {
                                if file.excelLocked {
                                    showingBuyCreditsAlert = true   // ✅ THIS TRIGGERS THE ALERT
                                } else {
                                    UIApplication.shared.open(file.url)
                                }
                            } label: {
                                HStack {
                                    Image(systemName: file.excelLocked ? "lock.fill" : "tablecells")
                                        .foregroundColor(file.excelLocked ? .red : .green)

                                    Text(file.excelLocked ? "Locked Excel" : file.name)
                                        .foregroundColor(.primary)

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.secondary)
                                }
                            }
                            .buttonStyle(.plain)
                            .alert("No Credits", isPresented: $showingBuyCreditsAlert) {
                                Button("Buy Credits") {
                                    // future: navigate to Credits tab
                                }
                                Button("Cancel", role: .cancel) {}
                            } message: {
                                Text("You need credits to unlock this Excel file.")
                            }
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(8)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
        // Extract Uplaods
    private var uploadButton: some View {
        Button {
            showingDocumentPicker = true
        } label: {
            Label("Upload New PDF", systemImage: "arrow.up.doc")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue.opacity(0.1))
                .foregroundColor(.blue)
                .cornerRadius(12)
        }
    }
    
    // MARK: - Scan Handling

    private func handleScanCompleted(_ newPanels: [Panel]) {
        panels.append(contentsOf: newPanels)

        guard let project = project else { return }

        projectService.savePanels(newPanels, for: project) {
            print("🎉 Panels saved after scan")
        }
    }
    func deletePDF(pdfId: String) {
        guard let currentProject = project else {
            print("❌ ProjectDetailView.deletePDF: project is nil")
            return
        }
        
        print("🧹 ProjectDetailView.deletePDF called for pdfId = \(pdfId)")
        
        let service = self.projectService
        service.deletePDF(project: currentProject, pdfId: pdfId)
        
        service.fetchProject(id: currentProject.id) { updated in
            if let updated = updated {
                print("✅ ProjectDetailView: project refreshed after delete, pdfFiles = \(updated.pdfFiles.count)")
                self.project = updated
            } else {
                print("⚠️ ProjectDetailView: fetchProject returned nil after delete")
            }
        }
    }
    var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text.viewfinder")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            Text("No PDFs Uploaded")
                .font(.headline)
            Text("Upload a panel schedule to begin scanning.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemBackground)))
        .padding(.horizontal)
    }
    func handlePDFImport(url: URL) {
        guard let currentProject = project else { return }
        projectService.uploadPDF(project: currentProject, fileURL: url)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            projectService.fetchProject(id: currentProject.id) { updatedProject in
                if let updated = updatedProject {
                    self.project = updated
                    print("✅ Project updated. Found \(updated.pdfFiles.count) files.")
                }
            }
        }
    }
}
// MARK: - Main Content

private extension ProjectDetailViewV2 {

    func content(_ project: Project) -> some View {
        NavigationStack {
            List {
                summarySection(project)
                documentsSection(project)
                extractedPanelsSection(project)
                outputsSection(project)
                projectInfoSection(project)
            }
            .listStyle(.insetGrouped)
            .navigationTitle(project.name)
        }
    }
}

// MARK: - Sections (PLACEHOLDERS, SAFE)

private extension ProjectDetailViewV2 {

  

    func extractedPanelsSection(_ project: Project) -> some View {
        Section("Extracted Panels") {
            Text("Extracted Panels placeholder")
                .foregroundStyle(.secondary)
        }
    }

    func outputsSection(_ project: Project) -> some View {
        Section("Outputs") {
            Text("Outputs placeholder")
                .foregroundStyle(.secondary)
        }
    }

    func projectInfoSection(_ project: Project) -> some View {
        Section("Project Info") {
            Text("Project Info placeholder")
                .foregroundStyle(.secondary)
        }
    }
}


struct ExcelRow: Identifiable {
    let id: String        // MUST be stable
    let name: String
    let url: URL
    let excelLocked: Bool

}

