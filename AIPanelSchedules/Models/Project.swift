//
//  Project.swift
//  AIPanelSchedules
//
//  Created by Kenneth Riendeau on 12/7/25.
//

import Foundation

struct Project: Identifiable, Codable {
    var id: String
    var name: String
    var created: Date
    var panels: [Panel]
    var pdfFiles: [PDFFile]          // ← NEW list of PDFs
    var selectedPageIndex: Int?
    var notes: String?
    var excelDownloadURL: String? // <--- ADD THIS LINE
    
    init(
        id: String = UUID().uuidString,
        name: String,
        created: Date = Date(),
        panels: [Panel] = [],
        pdfFiles: [PDFFile] = [],     // ← NEW param with default
        selectedPageIndex: Int? = nil,
        notes: String? = nil,
        excelDownloadURL: String? = nil // <--- Add to init param
    ) {
        self.id = id
        self.name = name
        self.created = created
        self.panels = panels
        self.pdfFiles = pdfFiles      // ← ASSIGN IT HERE
        self.selectedPageIndex = selectedPageIndex
        self.notes = notes
    }
}
