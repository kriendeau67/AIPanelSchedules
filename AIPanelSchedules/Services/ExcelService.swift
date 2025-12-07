//
//  ExcelService.swift
//  AIPanelSchedules
//
//  Created by Kenneth Riendeau on 12/8/25.
//
import FirebaseFunctions
import Foundation

class ExcelService {
    private let functions = Functions.functions(region: "us-central1")

    func generateWorkbook(projectId: String, panels: [Panel], completion: @escaping (Result<URL, Error>) -> Void) {

        let panelDicts = panels.map { $0.toDictionary() }

        let payload: [String: Any] = [
                "projectId": projectId,
                "panels": panelDicts
        ]

        // IMPORTANT: specify region or the function WILL NEVER RUN
        let callable = Functions.functions(region: "us-central1")
            .httpsCallable("generatePanelWorkbook")
        
        print("📤 Payload being sent to Cloud Function:")
        print(payload)
        
        callable.call(payload) { result, error in
                    if let error = error {
                        print("❌ Callable error:", error)
                        completion(.failure(error))
                        return
                    }

                    guard let data = result?.data as? [String: Any] else {
                        print("❌ No data returned from Cloud Function")
                        completion(.failure(NSError(domain: "ExcelService", code: -1)))
                        return
                    }

                    print("📦 Raw Cloud Function result:", data)

                    if let isError = data["error"] as? Bool, isError == true {
                        let message = data["message"] as? String ?? "Unknown error"
                        print("❌ Function-reported error:", message)
                        completion(.failure(NSError(domain: "ExcelService", code: -2,
                                                    userInfo: [NSLocalizedDescriptionKey: message])))
                        return
                    }

                    // JUST GET THE URL. NO TAMPERING.
                    if let urlString = data["url"] as? String, let url = URL(string: urlString) {
                        print("🔗 Generated URL: \(url.absoluteString)")
                        completion(.success(url))
                        return
                    }

                    print("❌ Invalid response format")
                    completion(.failure(NSError(domain: "ExcelService", code: -3)))
                }
    }
}
