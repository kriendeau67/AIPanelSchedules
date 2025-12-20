//
//  PDFFileCard.swift
//  AIPanelSchedules
//
//  Created by Kenneth Riendeau on 12/12/25.
//
import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct PDFFileCard: View {
    @State private var isGeneratingExcel = false
    @EnvironmentObject var projectService: ProjectService
//For backend changes
    @State private var scanJobListener: ListenerRegistration?
    @State private var scanJobId: String?
    // 1. INPUT FIX: Accept the ID instead of the entire project object
    let pdfUrl: URL
    let projectId: String // <--- NEW STABLE INPUT
    let panels: [Panel]
    let fileName: String
    let pdfId: String   // <-- Required to update the correct pdfFiles[] element
    let initialExcelUrlString: String?   // 👈 NEW
    let excelLocked: Bool
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
        case confirmScan

        var id: String {
            switch self {
            case .delete: return "delete"
            case .scanError: return "scanError"
            case .confirmScan: return "confirmScan"
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
        excelLocked: Bool,
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
        self.excelLocked = excelLocked
        self._currentScanningID = currentScanningID

        self.onViewPDF = onViewPDF
        self.onDeletePDF = onDeletePDF   // now it receives the pdfId
        self.onScanCompleted = onScanCompleted
        self.onExcelGenerated = onExcelGenerated
        print("📦 PDFFileCard init:", fileName, "excelLocked:", excelLocked)
    }
    // Computed Properties
    private var cardID: String { pdfUrl.absoluteString }
    
    private var isScanPending: Bool {
        return currentScanningID != nil && currentScanningID != cardID
    }
    
    private var hasBeenScanned: Bool {
        return panels.contains(where: {
            $0.sourcePDFID == pdfId
        })
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
               

    var body: some View    {
       
            PDFRowView(
                fileName: fileName,
                hasBeenScanned: hasBeenScanned,
                isScanning: isThisCardScanning,
                isScanPending: isScanPending,
                isGeneratingExcel: isGeneratingExcel,
                scanStatusText: scanStatusText,
                finalExcelURL: finalExcelURL,
                excelLocked: excelLocked,
                onExcelTap: handleExcelTap,
                onViewPDF: onViewPDF,
                onDelete: { activeAlert = .delete },
              //  onScan: startGeminiScan,
                onScan: {
                    activeAlert = .confirmScan
                },
                onGenerateExcel: generateExcel
            )
            .alert(item: $activeAlert) { type in
                switch type {
                case .delete:
                    return Alert(
                        title: Text("Delete PDF?"),
                        message: Text("This will permanently remove this file and its data."),
                        primaryButton: .destructive(Text("Delete")) {
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
                case .confirmScan:
                    return Alert(
                        title: Text("Confirm Panel Schedule"),
                        message: Text("""
                This PDF should be a **single-page electrical panel schedule**.

                Floor plans, risers, and one-line diagrams are not supported.

                Do you want to proceed with scanning?
                """),
                        primaryButton: .default(Text("Scan with AI")) {
                            startGeminiScan()   // ✅ ACTUAL scan happens here
                        },
                        secondaryButton: .cancel()
                    )
                }
            }
        }
    
    
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
                    Text("Scan with AI")
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
        createScanJob()

        isThisCardScanning = true
        currentScanningID = cardID
        listenForScanCompletion()   // 👈 ADD THIS

        print("🧾 Scan job created. Backend will handle Gemini + Excel.")

        // Optional: lightweight UI progress animation
        let _ = Task { await runProgressAnimation() }
    }
    private func createScanJob() {
        guard let uid = Auth.auth().currentUser?.uid else { return }

        let jobId = UUID().uuidString
        let db = Firestore.firestore()
        self.scanJobId = jobId   // 👈 ADD THIS

        let jobRef = db
            .collection("users")
            .document(uid)
            .collection("scanJobs")
            .document(jobId)

        let data: [String: Any] = [
            "id": jobId,
            "projectId": projectId,
            "pdfId": pdfId,
            "fileName": fileName,
            "urlString": pdfUrl.absoluteString,   // 🔑 ADD THIS
            "status": "queued",
            "createdAt": Timestamp(),
            "updatedAt": Timestamp()
        ]

        jobRef.setData(data) { error in
            if let error = error {
                print("❌ Failed to create ScanJob:", error.localizedDescription)
            } else {
                print("🧾 ScanJob created:", jobId)
            }
        }
    }
    private func handleExcelTap() {
        if excelLocked {
            // TEMP placeholder — Stripe URL comes next
            let stripeURL = URL(string: "https://createcheckoutsession-q2xfx4bbaq-uc.a.run.app")!
            UIApplication.shared.open(stripeURL)
        } else if let url = finalExcelURL {
            UIApplication.shared.open(url)
        }
    }
    // MARK: - Excel Generation (Corrected to use projectId)
    func generateExcel() {
        isGeneratingExcel = true
        // 1. Filter using the FILENAME
     //   let myPanels = panels.filter { $0.sourcePDFID == pdfUrl.lastPathComponent }
        let myPanels = panels.filter { $0.sourcePDFID == pdfId }
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
                        pdfFiles[index]["excelLocked"] = true
                        projectRef.updateData([
                            "pdfFiles": pdfFiles
                        ]) { error in
                            Task { @MainActor in
                                    self.isGeneratingExcel = false
                                }

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
                Task { @MainActor in
                        self.isGeneratingExcel = false
                    }
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
    private func listenForScanCompletion() {
        guard
            let uid = Auth.auth().currentUser?.uid,
            let jobId = scanJobId
        else { return }

        let jobRef = Firestore.firestore()
            .collection("users")
            .document(uid)
            .collection("scanJobs")
            .document(jobId)

        scanJobListener = jobRef.addSnapshotListener { snapshot, _ in
            guard let data = snapshot?.data(),
                  let status = data["status"] as? String else { return }

            switch status {

            case "finished":
                print("✅ Scan finished — loading panels")

                self.resetScanState()
                self.scanJobListener?.remove()
                self.scanJobListener = nil

                // 🔑 CRITICAL FIX: refresh project list FIRST
                self.projectService.loadProjects()

                // Then fetch panels for UI
                self.projectService.fetchProject(id: projectId) { project in
                    guard let project else { return }

                    self.projectService.fetchPanels(for: project) { panels in
                        DispatchQueue.main.async {
                            self.onScanCompleted(panels)
                        }
                    }
                }
            case "failed":
                print("❌ Scan failed")

                self.scanErrorMessage =
                    (data["errorMessage"] as? String)
                    ?? "Scan failed. Please try again."

                self.activeAlert = .scanError
                self.resetScanState()
                self.scanJobListener?.remove()
                self.scanJobListener = nil

            default:
                break
            }
        }
    }
}
