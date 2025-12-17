import Foundation
import FirebaseFirestore
import FirebaseAuth
import FirebaseStorage
import Combine

@MainActor
class ProjectService: ObservableObject {

    @Published var projects: [Project] = []
    private var db = Firestore.firestore()

    private var uid: String? {
        Auth.auth().currentUser?.uid
    }

    // MARK: - Load all projects
    // In ProjectService.swift:

    // You need a property to hold the listener registration so you can turn it off later (optional, but good practice)
    private var projectsListener: ListenerRegistration?

    func loadProjects() {
        guard let uid = uid else { return }

        // 1. If a listener already exists, stop it before starting a new one (to avoid duplicates)
        projectsListener?.remove()

        // 2. Switch to .addSnapshotListener for real-time updates
        projectsListener = db.collection("users")
            .document(uid)
            .collection("projects")
            .order(by: "created", descending: false)
            // CRITICAL CHANGE: Use addSnapshotListener instead of getDocuments
            .addSnapshotListener { snapshot, error in

                if let error = error {
                    print("Error setting up project listener:", error)
                    return
                }

                guard let documents = snapshot?.documents else {
                    self.projects = []
                    return
                }

                // Map and update the published projects array
                let loadedProjects = documents.map { doc in
                    // Your original mapping logic goes here, ensuring the Excel URL is read
                    let pdfFilesData = doc["pdfFiles"] as? [[String: Any]] ?? []
                    
                    let pdfFiles = pdfFilesData.compactMap { dict -> PDFFile? in
                        guard
                            let id = dict["id"] as? String,
                            let fileName = dict["fileName"] as? String,
                            let uploadedAtTimestamp = dict["uploadedAt"] as? Timestamp
                        else { return nil }
                        
                        let urlString = dict["urlString"] as? String
                        let excelUrl = dict["excelUrl"] as? String
                        let excelLocked = dict["excelLocked"] as? Bool   // 🔑 MISSING LINE

                        return PDFFile(
                            id: id,
                            fileName: fileName,
                            uploadedAt: uploadedAtTimestamp.dateValue(),
                            urlString: urlString,
                            excelUrl: excelUrl,
                            excelLocked: excelLocked                      // 🔑 ADD THIS
                        )
                    }

                    return Project(
                        id: doc.documentID,
                        name: doc["name"] as? String ?? "Untitled Project",
                        created: (doc["created"] as? Timestamp)?.dateValue() ?? Date(),
                        panels: [],
                        pdfFiles: pdfFiles,
                        selectedPageIndex: doc["selectedPageIndex"] as? Int,
                        notes: doc["notes"] as? String,
                        excelDownloadURL: doc["excelDownloadURL"] as? String // Ensure this is read!
                    )
                }
                for project in loadedProjects {
                    for pdf in project.pdfFiles {
                        print("🧪 PDF:", pdf.fileName, "excelLocked:", pdf.excelLocked as Any)
                    }
                }
                // 3. Update the published variable on the main thread
                DispatchQueue.main.async {
                    self.projects = loadedProjects
                }
            }
    }
    // MARK: - Create a new project
    func createProject(name: String) {
        guard let uid = uid else { return }

        let data: [String: Any] = [
            "name": name,
            "created": Date()
        ]

        db.collection("users")
            .document(uid)
            .collection("projects")
            .addDocument(data: data)
    }

    // MARK: - Delete project
    func deleteProject(_ project: Project) {
        guard let uid = Auth.auth().currentUser?.uid else { return }

        db.collection("users")
            .document(uid)
            .collection("projects")
            .document(project.id)
            .delete { error in
                if let error = error {
                    print("Error deleting project: \(error)")
                } else {
                    self.loadProjects()
                }
            }
    }
    
    // MARK: - Delete PDF
    func deletePDF(project: Project, pdfId: String) {
        guard let uid = uid else { return }

        let docRef = db.collection("users").document(uid)
            .collection("projects").document(project.id)

        // Remove the matching entry from Firestore array
        let updatedFiles = project.pdfFiles.filter { $0.id != pdfId }

        let payload = updatedFiles.map { file -> [String: Any] in
            return [
                "id": file.id,
                "fileName": file.fileName,
                "uploadedAt": Timestamp(date: file.uploadedAt),
                "urlString": file.urlString ?? "",
                "excelUrl": file.excelUrl ?? NSNull()
            ]
        }

        docRef.updateData([
            "pdfFiles": payload
        ]) { error in
            if let error = error {
                print("❌ Error updating pdfFiles during delete:", error)
            } else {
                print("🗑 Successfully removed PDF metadata")

                // ALSO delete from storage
                if let file = project.pdfFiles.first(where: { $0.id == pdfId }),
                   let urlString = file.urlString,
                   let url = URL(string: urlString) {

                    Storage.storage().reference(forURL: url.absoluteString).delete { error in
                        if let error = error {
                            print("⚠️ Storage delete error:", error)
                        } else {
                            print("🗑 Storage file removed successfully")
                        }
                    }
                }
            }
        }
    }
    // MARK: - Fetch a single project
    func fetchProject(id projectId: String, completion: @escaping (Project?) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else {
            completion(nil)
            return
        }

        db.collection("users")
            .document(uid)
            .collection("projects")
            .document(projectId)
            .getDocument { snapshot, error in

                if let data = snapshot?.data() {

                    let pdfFilesData = data["pdfFiles"] as? [[String: Any]] ?? []
                    let pdfFiles = pdfFilesData.compactMap { dict -> PDFFile? in
                        guard
                            let id = dict["id"] as? String,
                            let fileName = dict["fileName"] as? String,
                            let uploadedAt = (dict["uploadedAt"] as? Timestamp)?.dateValue()
                        else { return nil }
                        
                        let urlString = dict["urlString"] as? String
                        let excelUrl = dict["excelUrl"] as? String
                        let excelLocked = dict["excelLocked"] as? Bool   // 🔑 ADD

                        return PDFFile(
                            id: id,
                            fileName: fileName,
                            uploadedAt: uploadedAt,
                            urlString: urlString,
                            excelUrl: excelUrl,
                            excelLocked: excelLocked                      // 🔑 ADD
                        )
                    }

                    let updated = Project(
                        id: snapshot?.documentID ?? projectId,
                        name: data["name"] as? String ?? "Untitled Project",
                        created: (data["created"] as? Timestamp)?.dateValue() ?? Date(),
                        panels: [],
                        pdfFiles: pdfFiles,
                        selectedPageIndex: data["selectedPageIndex"] as? Int,
                        notes: data["notes"] as? String,
                        excelDownloadURL: data["excelDownloadURL"] as? String // <--- ADD THIS
                    )

                    completion(updated)
                } else {
                    completion(nil)
                }
            }
    }

    // MARK: - Fetch Panels
    func fetchPanels(for project: Project, completion: @escaping ([Panel]) -> Void) {
        guard let uid = uid else {
            print("❌ No authenticated user ID")
            completion([])
            return
        }

        let path = "users/\(uid)/projects/\(project.id)/panels"
        Firestore.firestore()
            .collection(path)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("❌ Error fetching panels:", error)
                    completion([])
                    return
                }

                let panels = snapshot?.documents.compactMap { doc -> Panel? in
                    try? doc.data(as: Panel.self)
                } ?? []

                completion(panels)
            }
    }
    // --- PASTE THIS IN ProjectService.swift ---

    func saveExcelURL(
        projectId: String,
        pdfId: String,
        excelUrl: String
    ) {
        guard let uid = Auth.auth().currentUser?.uid else {
            print("❌ No user ID. Cannot save Excel URL.")
            return
        }

        print("⚡️ Saving Excel URL for PDF \(pdfId) in project \(projectId)")

        let db = Firestore.firestore()
        let projectRef = db.collection("users")
            .document(uid)
            .collection("projects")
            .document(projectId)

        projectRef.getDocument { snapshot, error in
            if let error = error {
                print("❌ Error fetching project to update pdfFiles:", error)
                return
            }
            guard var data = snapshot?.data(),
                  var pdfFiles = data["pdfFiles"] as? [[String: Any]] else {
                print("❌ Could not read existing pdfFiles array")
                return
            }

            // 🔄 Update ONLY the matching PDF entry
            for i in 0..<pdfFiles.count {
                if let id = pdfFiles[i]["id"] as? String, id == pdfId {
                    pdfFiles[i]["excelUrl"] = excelUrl
                }
            }

            // 🔥 Write updated list back to Firestore
            projectRef.updateData([
                "pdfFiles": pdfFiles
            ]) { error in
                if let error = error {
                    print("❌ Failed to save Excel URL:", error.localizedDescription)
                } else {
                    print("✅ Excel URL saved successfully INTO THE PDF ENTRY.")
                }
            }
        }
    }
}

// MARK: - Storage (upload & download)
extension ProjectService {
    
    // MARK: - Save extracted panels for a project
    func savePanels(_ panels: [Panel], for project: Project, completion: (() -> Void)? = nil) {
        guard let uid = Auth.auth().currentUser?.uid else {
            print("❌ No UID when trying to save panels")
            completion?()
            return
        }

        let projectRef = db.collection("users")
            .document(uid)
            .collection("projects")
            .document(project.id)

        let panelsRef = projectRef.collection("panels")
        
        // --- CHANGE 1: DO NOT DELETE EXISTING PANELS ---
        // We just start writing the new ones immediately.

        let group = DispatchGroup()

        for panel in panels {
            group.enter()

            // Use panel.name as the document ID (e.g. "LPH1")
            // NOTE: If you have two panels named "LPH1" in different PDFs, this will overwrite.
            // If that is a risk, consider using UUID().uuidString as the ID instead.
            let docId = panel.name.isEmpty ? UUID().uuidString : panel.name

            // Convert circuits into [ [String: Any] ]
            let circuitsData: [[String: Any]] = panel.circuits.map { circuit in
                var dict: [String: Any] = [
                    "number": circuit.number
                ]
                if let desc = circuit.description {
                    dict["description"] = desc
                }
                if let trip = circuit.tripAmps {
                    dict["tripAmps"] = trip
                }
                if let poles = circuit.poles {
                    dict["poles"] = poles
                }
                return dict
            }

            let panelData: [String: Any] = [
                "name": panel.name,
                "sourcePDFID": panel.sourcePDFID as Any, // <--- CHANGE 2: SAVE THE ID
                "location": panel.location as Any,
                "voltage": panel.voltage as Any,
                "phases": panel.phases as Any,
                "mains": panel.mains as Any,
                "circuits": circuitsData
            ]

            // merge: true ensures we update fields without destroying other data if it exists
            panelsRef.document(docId).setData(panelData, merge: true) { error in
                if let error = error {
                    print("❌ Error saving panel \(panel.name):", error)
                } else {
                    print("✅ Saved panel \(panel.name)")
                }
                group.leave()
            }
        }

        // After all panel writes finish, mark the project as having extracted panels
        group.notify(queue: .main) {
            // We need to increment the count, not just set it to the current batch size.
            // For now, setting hasExtractedPanels is sufficient.
            let meta: [String: Any] = [
                "hasExtractedPanels": true
                // Removed "panelCount" overwrite to avoid bad math.
            ]
            projectRef.setData(meta, merge: true) { error in
                if let error = error {
                    print("⚠️ Error updating project panel metadata:", error)
                } else {
                    print("✅ Project metadata updated")
                }
                completion?()
            }
        }
    }
    
    // MARK: - Load Panels
    func loadPanels(for project: Project, completion: @escaping ([Panel]) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else {
            completion([])
            return
        }

        db.collection("users")
            .document(uid)
            .collection("projects")
            .document(project.id)
            .collection("panels")
            .getDocuments { snapshot, error in

                if let error = error {
                    print("❌ Error loading panels:", error)
                    completion([])
                    return
                }

                let panels: [Panel] = snapshot?.documents.compactMap { doc in
                    try? doc.data(as: Panel.self)
                } ?? []

                completion(panels)
            }
    }

    // MARK: - Upload PDF
    func uploadPDF(project: Project, fileURL: URL) {
        guard let uid = Auth.auth().currentUser?.uid else { return }

        // 1. Create a UNIQUE filename
        let uniqueFileName = "\(UUID().uuidString).pdf"
        let path = "users/\(uid)/projectFiles/\(project.id)/\(uniqueFileName)"
        let ref = Storage.storage().reference().child(path)

        print("📤 Starting upload to: \(path)")

        // 2. Upload the file
        ref.putFile(from: fileURL, metadata: nil) { metadata, error in
            if let error = error {
                print("❌ Error uploading PDF:", error.localizedDescription)
                return
            }

            // 3. Get the Download URL
            ref.downloadURL { url, error in
                guard let downloadURL = url else {
                    print("❌ Upload finished, but failed to get Download URL:", error?.localizedDescription ?? "Unknown error")
                    return
                }
                
                print("✅ Got Download URL: \(downloadURL.absoluteString)")

                // --- THE FIX: WAIT 1 SECOND BEFORE SAVING TO DB ---
                // This ensures the upload connection is fully closed before the UI tries to read the new file.
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    
                    // 4. Save Metadata WITH the URL
                    self.savePDFMetadata(project: project,
                                         fileName: fileURL.lastPathComponent,
                                         downloadURL: downloadURL.absoluteString)
                }
                // --------------------------------------------------
            }
        }
    }

    // MARK: - Save PDF Metadata (Helper)
    private func savePDFMetadata(project: Project, fileName: String, downloadURL: String) {
        guard let uid = uid else { return }
        
        let docRef = db.collection("users")
            .document(uid)
            .collection("projects")
            .document(project.id)

        docRef.getDocument { snapshot, error in
            var existing = snapshot?.data()?["pdfFiles"] as? [[String: Any]] ?? []

            // Build the new entry
            let newEntry: [String: Any] = [
                "id": UUID().uuidString,
                "fileName": fileName,
                "uploadedAt": Timestamp(date: Date()),
                "urlString": downloadURL,
                "excelUrl": NSNull(),
                "excelLocked": true
                // keep field consistent
            ]

            // ❌ Remove duplicates based on fileName (OR better: based on URL)
            existing.removeAll { $0["fileName"] as? String == fileName }

            // ✔ Append fresh entry
            existing.append(newEntry)

            // Write back
            docRef.updateData([
                "pdfFiles": existing
            ]) { error in
                if let error = error {
                    print("❌ Error saving PDF metadata:", error)
                } else {
                    print("✅ PDF metadata updated without duplicates")
                }
            }
        }
    }
    
    // MARK: - Download PDF (Legacy/Helper)
    func downloadPDF(project: Project, completion: @escaping (Data?) -> Void) {
        // Updated to grab the FIRST available file if no specific file is requested
        // But mainly relying on the URL based viewing now.
        guard
            let uid = Auth.auth().currentUser?.uid,
            let fileName = project.pdfFiles.first?.fileName
        else {
            completion(nil)
            return
        }

        // Note: This logic assumes the fileName in the struct matches the one in Storage.
        // With UUID filenames, you might want to adjust logic if you ever use this function.
        // For now, leaving as-is since your new UI uses URLs directly.
        let path = "users/\(uid)/projectFiles/\(project.id)/\(fileName)"
        let ref = Storage.storage().reference().child(path)

        ref.getData(maxSize: 20 * 1024 * 1024) { data, error in
            if let error = error {
                print("Error downloading PDF:", error)
                completion(nil)
            } else {
                completion(data)
            }
        }
    }
    
}
