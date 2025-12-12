
import SwiftUI
import PDFKit
import FirebaseAuth
import FirebaseFirestore
import Combine

// MARK: - Helper Structs
struct PDFSheetItem: Identifiable {
    let id = UUID()
    let url: URL
}

// MARK: - Main Project View
struct ProjectDetailView: View {
    
    @EnvironmentObject var projectService: ProjectService

    // 1. INPUT: Accept the Project ID (Resolves the ProjectsListView compile error)
    let projectId: String
    
    // 2. PRIMARY DATA: Holds the live project data once fetched.
    @State private var project: Project? = nil
    
    // --- All other @State variables ---
    @State private var currentScanningPDFID: String? = nil
    @State private var showingDocumentPicker = false
    @State private var activePDFSheet: PDFSheetItem?
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

    // MARK: - View Body
    var body: some View {
        // Conditional Rendering: Only show content when data is loaded
        if let project = project {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    
                    // MARK: Header Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text(project.name)
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        
                        Text("\(project.pdfFiles.count) PDF Files Uploaded")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    .padding(.top)
                    
                    // MARK: PDF Cards List Old
              /*      if project.pdfFiles.isEmpty {
                        emptyStateView
                    } else {
                        LazyVStack(spacing: 20) {
                            ForEach(project.pdfFiles, id: \.id) { file in
                                if let pdfUrl = file.url {
                                    PDFFileCard(
                                        pdfUrl: pdfUrl,
                                        projectId: projectId,
                                        pdfId: file.id,
                                        panels: panels,
                                        fileName: file.fileName,
                                        initialExcelUrlString: file.excelUrl,
                                        currentScanningID: $currentScanningPDFID,
                                        onViewPDF: {
                                            self.activePDFSheet = PDFSheetItem(url: pdfUrl)
                                        },
                                        onDeletePDF: { id in
                                            deletePDF(pdfId: id)
                                        },
                                        onScanCompleted: { newPanels in
                                            self.panels.append(contentsOf: newPanels)
                                            self.projectService.savePanels(newPanels, for: project) {
                                                print("🎉 Save complete!")
                                            }
                                        },
                                        onExcelGenerated: {
                                            self.refreshProjectData()
                                        }
                                    )
                                }
                            }
                        }
                        .padding(.horizontal)
                    } */
                    // New--------
                    
                    // MARK: Footer Actions
                    VStack(spacing: 16) {
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
                        
                        if !panels.isEmpty {
                            NavigationLink(destination: PanelListView(panels: panels)) {
                                HStack {
                                    Text("View All Extracted Panels")
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                }
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                            }
                            .foregroundColor(.primary)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 40)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingDocumentPicker) {
                DocumentPicker { url in
                    handlePDFImport(url: url)
                }
            }
            .sheet(item: $activePDFSheet) { item in
                AsyncPDFViewer(url: item.url)
            }
            .onAppear {
                refreshProjectData()   // THIS handles panel loading safely AFTER project reload
            }
            .onReceive(projectService.$projects) { _ in
                Task { @MainActor in
                    print("🔄 Projects list changed — refreshing project data inside DetailView")
                    self.refreshProjectData()
                }
            }
            
        } else {
            // Loader while data is fetching
            ProgressView("Loading Project Data...")
                // Initial fetch when the view first appears
                .onAppear(perform: refreshProjectData)
        }
    }
    
    // MARK: - Logic Functions
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
    
    // MARK: - Subviews & Helpers
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
}


// MARK: - Placeholder Structs (Ensure these are in your file if needed for compilation)



