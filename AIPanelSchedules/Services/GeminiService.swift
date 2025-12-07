//
//  GeminiService.swift
//  AIPanelSchedules
//

import Foundation
import UIKit
import PDFKit

class GeminiService {
    
    static let shared = GeminiService()
    
    private init() {}
    
    // MARK: - Helper: Extract Single Page as PDF Data
    // Use this when the user picks a page. It prevents sending a huge 50MB file to Gemini.
    func dataForSinglePage(from pdfUrl: URL, pageIndex: Int) -> Data? {
        guard let document = PDFDocument(url: pdfUrl),
              let page = document.page(at: pageIndex) else {
            return nil
        }
        
        // Create a new distinct PDF document for just this one page
        let singlePagePDF = PDFDocument()
        singlePagePDF.insert(page, at: 0)
        
        return singlePagePDF.dataRepresentation()
    }
    
    // get valid api list
    func listAvailableModels() async {
        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models?key=\(Secrets.geminiAPIKey)")!
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let json = try? JSONSerialization.jsonObject(with: data) {
                print("📋 AVAILABLE MODELS:")
                print(json)
            }
        } catch {
            print("Error listing models: \(error)")
        }
    }
    // MARK: - Main method: Send PDF Data -> Get Panels
    
    func extractPanels(from pdfData: Data) async throws -> PanelResponse {
        // await listAvailableModels()
        
        // USE THIS EXACT URL FOR PRODUCTION
        let url = URL(string:
                        "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-pro:generateContent"
        )!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 180  // allow 3 minutes for PDF analysis
        request.setValue(Secrets.geminiAPIKey, forHTTPHeaderField: "x-goog-api-key")
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        
        // 2) PDF Data → base64
        // No rendering to image needed. We send the raw vector PDF.
        let base64PDF = pdfData.base64EncodedString()
        
        // 3) System instruction
        let systemInstruction = """
        You are an expert at interpreting electrical panel schedules from construction drawings.
        
        The file is a single PDF sheet that contains MULTIPLE panel schedules arranged in a grid (often 9+ panels).
        
        Your ONLY task is to extract EVERY panel schedule visible in the provided file and return them in a STRICT JSON OBJECT format.
        You MUST extract EVERY panel on the page.
        Do NOT stop early.
        Continue extracting panels until the entire PDF page has been fully scanned.
        
        ⚠️ CRITICAL INSTRUCTION:
        - The PDF likely contains 6, 9, or more panels. Do NOT stop after the first one.
        - Scan the entire width and height of the page.
        - Return ALL panels found.
        
        Extract the "Fed From" field exactly as it appears in each panel header (for example: "Fed From: MDP"). Return it in the "fedFrom" property for each panel.
        
        ⚠️ OUTPUT RULES:
        1. Your response MUST be a single JSON OBJECT.
        2. The top-level key MUST be exactly: "panels"
        3. The value of "panels" MUST be an array of panel objects.
        4. NEVER wrap the JSON in markdown fences like ```json.
        5. NEVER add prose, explanation, or comments.
        
        Required JSON Structure:
        {
          "panels": [
            {
              "name": "string",
              "location": "string or null",
              "voltage": "string or null",
              "phases": "string or null",
              "mains": "string or null",
              "fedFrom": "string or null",
              "circuits": [
                {
                  "number": 1,
                  "description": "string",
                  "tripAmps": 20,
                  "poles": 1
                }
              ]
            }
          ]
        }
        """
        
        // 4) Build JSON body for Gemini
        // Note the mime_type is now application/pdf
        let requestBody = GeminiRequest(
            contents: [
                GeminiContentRequest(
                    role: "user",
                    parts: [
                        GeminiPartRequest(
                            text: nil,
                            inline_data: InlineDataRequest(
                                mime_type: "application/pdf",
                                data: base64PDF
                            )
                        ),
                        GeminiPartRequest(
                            text: systemInstruction,
                            inline_data: nil
                        )
                    ]
                )
            ]
        )
        let encoder = JSONEncoder()
        let bodyData = try encoder.encode(requestBody)
        request.httpBody = bodyData
        
        // 5) Send request
        // --- NEW TIMEOUT PROTECTION ---
        // Create a custom session so it doesn't time out after 60s
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 180 // 3 minutes
        config.timeoutIntervalForResource = 300 // 5 minutes
        let session = URLSession(configuration: config)

        let (data, response) = try await session.data(for: request)
        // -----------------------------
        // Check for non-200 HTTP status
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            let errorText = String(data: data, encoding: .utf8) ?? "Unknown Error"
            print("❌ API Error \(httpResponse.statusCode): \(errorText)")
            throw URLError(.badServerResponse)
        }
        
        // ---- Decode Logic (Same as before) ----
        let wrapper = try JSONDecoder().decode(GeminiWrapper.self, from: data)
        
        guard
            let candidates = wrapper.candidates,
            let firstCandidate = candidates.first,
            let firstPart = firstCandidate.content.parts.first,
            let text = firstPart.text
        else {
            print("⚠️ No text parts found in Gemini response")
            return PanelResponse(panels: [])
        }
        
        let cleanedJSON = stripMarkdownFences(text)
        print("🧹 Cleaned JSON from Gemini: \(cleanedJSON.prefix(100))...") // Print snippet to keep console clean
        
        guard let jsonData = cleanedJSON.data(using: .utf8) else {
            print("❌ Could not turn cleaned JSON into Data")
            return PanelResponse(panels: [])
        }
        
        do {
            let result = try JSONDecoder().decode(PanelResponse.self, from: jsonData)
            print("✅ Successfully decoded \(result.panels.count) panels.")
            return result
        } catch {
            print("❌ Failed to decode PanelResponse:", error)
            return PanelResponse(panels: [])
        }
    }
    
    // MARK: - Utilities & Structs
    
    private func stripMarkdownFences(_ text: String) -> String {
        return text
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```JSON", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    struct GeminiRequest: Codable {
        let contents: [GeminiContentRequest]
    }
    
    struct GeminiContentRequest: Codable {
        let role: String?
        let parts: [GeminiPartRequest]
    }
    
    struct GeminiPartRequest: Codable {
        let text: String?
        let inline_data: InlineDataRequest?
    }
    
    struct InlineDataRequest: Codable {
        let mime_type: String
        let data: String
    }
    
    struct GeminiWrapper: Codable {
        let candidates: [GeminiCandidate]?
    }
    
    struct GeminiCandidate: Codable {
        let content: GeminiContent
    }
    
    struct GeminiContent: Codable {
        let parts: [GeminiPart]
    }
    
    struct GeminiPart: Codable {
        let text: String?
    }
}
