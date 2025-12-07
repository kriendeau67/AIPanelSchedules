
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
                    
                    // MARK: PDF Cards List
                    // MARK: PDF Cards List
                    if project.pdfFiles.isEmpty {
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
                    }
                    
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

struct PanelListView: View {
    let panels: [Panel]
    var body: some View {
        // ... (body content)
        Text("Panel List View")
    }
}

struct AsyncPDFViewer: View {
    let url: URL
    @State private var pdfDocument: PDFDocument?
    @State private var loading = true
    @State private var errorMessage: String?
    
    var body: some View {
        // ... (body content)
        Text("Async PDF Viewer")
    }
    // ... (loadPDF function)
}

struct PDFKitRepresentedView: UIViewRepresentable {
    let document: PDFDocument
    // ... (makeUIView and updateUIView)
    func makeUIView(context: Context) -> PDFView { return PDFView() }
    func updateUIView(_ uiView: PDFView, context: Context) {}
}

// MARK: - The Professional Card View (Sub-Component)


struct PDFFileCard: View {
    
    @EnvironmentObject var projectService: ProjectService

    // 1. INPUT FIX: Accept the ID instead of the entire project object
    let pdfUrl: URL
    let projectId: String // <--- NEW STABLE INPUT
    let panels: [Panel]
    let fileName: String
    let pdfId: String   // <-- Required to update the correct pdfFiles[] element
    let initialExcelUrlString: String?   // 👈 NEW

    // Bindings for Parent Communication
    @Binding var currentScanningID: String?
    
    // Actions
    var onViewPDF: () -> Void
    var onDeletePDF: (String) -> Void
    var onScanCompleted: ([Panel]) -> Void
    var onExcelGenerated: () -> Void // Added for parent refresh
    
    enum ActiveAlert: Identifiable {
        case delete
        case scanError

        var id: String {
            switch self {
            case .delete: return "delete"
            case .scanError: return "scanError"
            }
        }
    }

    @State private var activeAlert: ActiveAlert?
    // Local State
    @State private var tempExcelURL: URL?
    @State private var showAlert = false
    @State private var isThisCardScanning = false
    @State private var scanStatusText = "Scanning with Gemini..."
    @State private var showScanError = false
    @State private var scanErrorMessage = ""
    init(
        pdfUrl: URL,
        projectId: String,
        pdfId: String,
        panels: [Panel],
        fileName: String,
        initialExcelUrlString: String?,
        currentScanningID: Binding<String?>,
        onViewPDF: @escaping () -> Void,
        onDeletePDF: @escaping (String) -> Void,
        onScanCompleted: @escaping ([Panel]) -> Void,
        onExcelGenerated: @escaping () -> Void
    ) {
        self.pdfUrl = pdfUrl
        self.projectId = projectId
        self.pdfId = pdfId
        self.panels = panels
        self.fileName = fileName
        self.initialExcelUrlString = initialExcelUrlString

        self._currentScanningID = currentScanningID

        self.onViewPDF = onViewPDF
        self.onDeletePDF = onDeletePDF   // now it receives the pdfId
        self.onScanCompleted = onScanCompleted
        self.onExcelGenerated = onExcelGenerated
    }
    // Computed Properties
    private var cardID: String { pdfUrl.absoluteString }
    
    private var isScanPending: Bool {
        return currentScanningID != nil && currentScanningID != cardID
    }
    
    private var hasBeenScanned: Bool {
        return panels.contains(where: { $0.sourcePDFID == pdfUrl.lastPathComponent })
    }
    
    // MARK: - Final Excel Persistence Logic (Uses the stable projectId)
    private var finalExcelURL: URL? {
        // 1. Prefer the new temp URL right after generation
        if let temp = tempExcelURL {
            return temp
        }
        // 2. Otherwise, use whatever was loaded from Firestore for THIS pdf
        if let stored = initialExcelUrlString, let url = URL(string: stored) {
            return url
        }
        return nil
    }
               

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            
            // 1. Card Header
            HStack {
                // ... (existing header code) ...
                Image(systemName: "doc.fill")
                    .foregroundColor(.red)
                    .font(.title2)
                
                VStack(alignment: .leading) {
                    Text(fileName)
                        .font(.headline)
                        .lineLimit(1)
                    Text("PDF Document")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Delete Button
                Button(action: {
                    print("🟥 Trash tapped!")   // <--- ADD THIS

                    activeAlert = .delete }
                ) {
                    Image(systemName: "trash")
                        .foregroundColor(.gray)
                        .padding(8)
                        .background(Color(.systemGray6))
                        .clipShape(Circle())
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            
            Divider()
            
            // 2. Card Actions Area
            VStack(spacing: 12) {
                
                // ROW 1: PDF Actions
                HStack {
                    Button(action: onViewPDF) {
                        Label("View PDF", systemImage: "eye")
                            .font(.subheadline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.bordered)
                    .tint(.blue)
                    
                    if hasBeenScanned {
                        if finalExcelURL == nil {
                            Button(action: generateExcel) {
                                Label("Create Excel", systemImage: "tablecells")
                                    .font(.subheadline)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                            }
                            .buttonStyle(.bordered)
                            .tint(.green)
                        }
                    }
                }
                
                // ROW 2: Gemini Scan Action
                if !hasBeenScanned || isThisCardScanning {
                    scanButton
                } else {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Scan Complete")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.top, 4)
                }
                
                // FINAL: Excel Download Link (appears after generation)
                if let url = finalExcelURL {
                    Link(destination: url) {
                        HStack {
                            Image(systemName: "arrow.down.circle.fill")
                            Text("Download .xlsx File")
                        }
                        .font(.headline)
                        .foregroundColor(.blue)
                        .padding(.top, 4)
                    }
                }
            }
            .padding()
        }
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.08), radius: 5, x: 0, y: 2)
        // Alerts... (assuming they are correct)
        .alert(item: $activeAlert) { type in
            switch type {

            case .delete:
                return Alert(
                    title: Text("Delete PDF?"),
                    message: Text("This will permanently remove this file and its data. This action cannot be undone."),
                    primaryButton: .destructive(Text("Delete")) {
                        print("🧨 PDFFileCard: Delete confirmed for pdfId = \(pdfId)")
                        onDeletePDF(pdfId)
                    },
                    secondaryButton: .cancel()
                )

            case .scanError:
                return Alert(
                    title: Text("Scan Failed"),
                    message: Text(scanErrorMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
        }    }
    
    // MARK: - Component Views (scanButton, scanButtonBackground are unchanged)
    var scanButton: some View {
        Button(action: startGeminiScan) {
            HStack {
                if isThisCardScanning {
                    ProgressView()
                        .tint(.white)
                        .padding(.trailing, 5)
                    Text(scanStatusText)
                        .font(.subheadline)
                        .id(scanStatusText)
                        .transition(.opacity.animation(.easeInOut))
                } else if isScanPending {
                    Image(systemName: "hourglass")
                    Text("Pending (Scanner Busy)")
                } else {
                    Image(systemName: "sparkles")
                    Text("Scan with Gemini")
                }
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(scanButtonBackground)
            .cornerRadius(12)
        }
        .disabled(isThisCardScanning || isScanPending)
    }
    
    var scanButtonBackground: Color {
        if isThisCardScanning { return Color.purple }
        if isScanPending { return Color.gray }
        return Color.blue
    }
    
    // MARK: - Logic (startGeminiScan is largely unchanged)
    func startGeminiScan() {
        isThisCardScanning = true
        currentScanningID = cardID
        
        print("✨ Starting AI Scan for: \(pdfUrl.lastPathComponent)")
        
        let _ = Task { await runProgressAnimation() }

        Task {
            do {
                // ... (unchanged download logic) ...
                var request = URLRequest(url: pdfUrl)
                request.cachePolicy = .reloadIgnoringLocalCacheData
                request.timeoutInterval = 600
                
                let (data, _) = try await URLSession.shared.data(for: request)
                
                print("✅ Download complete (Size: \(data.count) bytes). Sending to Gemini...")

                let response = try await GeminiService.shared.extractPanels(from: data)
                
                var stampedPanels = response.panels
                for i in 0..<stampedPanels.count {
                    stampedPanels[i].sourcePDFID = pdfUrl.lastPathComponent
                }
                
                await MainActor.run {
                    print("🎉 Scan Success. Panels found: \(stampedPanels.count)")
                    self.onScanCompleted(stampedPanels)
                    self.resetScanState()
                }
                
            } catch {
                print("❌ Scan Error: \(error.localizedDescription)")
                await MainActor.run {
                    self.scanErrorMessage = "The scan failed. Please check your connection.\n\nDetails: \(error.localizedDescription)"
                    self.activeAlert = .scanError
                    self.resetScanState()
                }
            }
        }
    }

    // MARK: - Excel Generation (Corrected to use projectId)
    func generateExcel() {
        // 1. Filter using the FILENAME
        let myPanels = panels.filter { $0.sourcePDFID == pdfUrl.lastPathComponent }
        
        print("📊 Generating Excel for \(fileName). Found \(myPanels.count) panels.")

        // 2. Send only these panels, using the stable projectId
        ExcelService().generateWorkbook(projectId: projectId, panels: myPanels) { result in
            switch result {
            case .success(let url):
                // 1) Show it immediately in this card
                Task { @MainActor in
                    self.tempExcelURL = url
                }

                print("⚡️ ATTEMPTING MANUAL SAVE of Excel URL into THIS PDF entry…")

                guard let uid = Auth.auth().currentUser?.uid else { return }
                let db = Firestore.firestore()
                let projectRef = db.collection("users")
                    .document(uid)
                    .collection("projects")
                    .document(projectId)

                // 2) Read the current pdfFiles array, patch the matching one, write it back
                projectRef.getDocument { snapshot, error in
                    if let error = error {
                        print("❌ Failed to fetch project for Excel save: \(error.localizedDescription)")
                        return
                    }

                    guard var data = snapshot?.data(),
                          var pdfFiles = data["pdfFiles"] as? [[String: Any]] else {
                        print("❌ No pdfFiles array found on project when saving Excel.")
                        return
                    }

                    if let index = pdfFiles.firstIndex(where: { ($0["id"] as? String) == pdfId }) {

                        // 🔑 Store the Excel URL on this PDF
                        pdfFiles[index]["excelUrl"] = url.absoluteString

                        projectRef.updateData([
                            "pdfFiles": pdfFiles
                        ]) { error in
                            if let error = error {
                                print("❌ Failed to update pdfFiles with Excel URL: \(error.localizedDescription)")
                            } else {
                                print("✅ Excel URL saved into pdfFiles[\(index)] for file \(fileName)")
                                // refresh in-memory projects + tell parent view to refresh
                                self.projectService.loadProjects()
                                self.onExcelGenerated()
                            }
                        }

                    } else {
                        print("⚠️ Could not find pdfFiles entry matching fileName \(fileName) when saving Excel URL.")
                    }
                }

            case .failure(let error):
                print("❌ Excel Error: \(error)")
            }
        }
                
    }
    
    // MARK: - Animation Function (unchanged)
    func resetScanState() {
        isThisCardScanning = false
        currentScanningID = nil
    }
    
    func runProgressAnimation() async {
        // ... (your existing animation code) ...
        func updateStatus(_ text: String) async {
            await MainActor.run { self.scanStatusText = text }
        }

        await updateStatus("Initializing Gemini...")
        
        try? await Task.sleep(nanoseconds: 2 * 1_000_000_000)
        if !isThisCardScanning { return }
        await updateStatus("Scanning PDF Layout...")
        
        try? await Task.sleep(nanoseconds: 5 * 1_000_000_000)
        if !isThisCardScanning { return }
        await updateStatus("Identifying Panel Schedules...")
        
        try? await Task.sleep(nanoseconds: 10 * 1_000_000_000)
        if !isThisCardScanning { return }
        await updateStatus("Extracting Circuits & Voltages...")
        
        try? await Task.sleep(nanoseconds: 15 * 1_000_000_000)
        if !isThisCardScanning { return }
        await updateStatus("Continuing AI Magic...")
        
        try? await Task.sleep(nanoseconds: 20 * 1_000_000_000)
        if !isThisCardScanning { return }
        await updateStatus("Finalizing Data...")
    }
}
struct PDFRowView: View {
    // PASS IN DATA: We pass the specific PDF file to this view
    let pdf: URL
    
    // LOCAL STATE: These only belong to THIS specific row now!
    @State private var isScanning = false
    @State private var scanStatus = "Ready"
    @State private var excelUrl: URL? // Each row has its own resulting file
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(pdf.lastPathComponent) // The PDF Name
                .font(.headline)
            
            if let excelUrl = excelUrl {
                // SUCCESS STATE: Show the Excel Button
                ShareLink(item: excelUrl) {
                    Label("Open Excel Report", systemImage: "tablecells")
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            } else {
                // SCAN STATE: Show the Scan Button
                Button(action: {
                    performScan()
                }) {
                    HStack {
                        if isScanning {
                            ProgressView()
                                .tint(.white)
                            Text(scanStatus)
                        } else {
                            Text("Scan with Gemini")
                            Image(systemName: "sparkles")
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(isScanning ? Color.gray : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(isScanning)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    func performScan() {
        isScanning = true
        
        Task {
            // 1. Simulate finding data
            scanStatus = "Analyzing PDF..."
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second pause
            
            // 2. Simulate structuring
            scanStatus = "Structuring Data..."
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second pause
            
            // 3. The actual work (You will put your Gemini function here)
            scanStatus = "Finalizing..."
            
            // --- REPLACE THIS WITH YOUR ACTUAL GEMINI CALL ---
            // let result = await generateExcel(from: pdf)
            // excelUrl = result
            
            // For now, I'll simulate a success so you can test the UI
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            isScanning = false
        }
    }
}

