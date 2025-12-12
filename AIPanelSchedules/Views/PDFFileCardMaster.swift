//
//  PDFFileCardMaster.swift
//  AIPanelSchedules
//
//  Created by Kenneth Riendeau on 12/12/25.
//

//
//  PDFFileCard.swift
//  AIPanelSchedules
//
//  Created by Kenneth Riendeau on 12/12/25.
//
import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct PDFFileCardMaster: View {
    
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
