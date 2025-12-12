//
//  PDFRowViewMaster.swift
//  AIPanelSchedules
//
//  Created by Kenneth Riendeau on 12/12/25.
//

//
//  PDFRowView.swift
//  AIPanelSchedules
//
//  Created by Kenneth Riendeau on 12/12/25.
//
import SwiftUI

struct PDFRowViewMaster: View {
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

