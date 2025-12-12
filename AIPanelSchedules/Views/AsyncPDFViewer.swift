//
//  AsyncPDFViewer.swift
//  AIPanelSchedules
//
//  Created by Kenneth Riendeau on 12/12/25.
//

import SwiftUI
import PDFKit

// MARK: - Async PDF Viewer

struct AsyncPDFViewer: View {
    let url: URL

    @State private var pdfDocument: PDFDocument?
    @State private var loading = true
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if loading {
                ProgressView("Loading PDF…")
            } else if let pdfDocument {
                PDFKitRepresentedView(document: pdfDocument)
                    .edgesIgnoringSafeArea(.all)
            } else if let errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .padding()
            } else {
                Text("Failed to load PDF")
            }
        }
        .task {
            await loadPDF()
        }
    }

    @MainActor
    private func loadPDF() async {
        loading = true
        errorMessage = nil

        let accessed = url.startAccessingSecurityScopedResource()
        defer {
            if accessed { url.stopAccessingSecurityScopedResource() }
        }

        guard let document = PDFDocument(url: url) else {
            errorMessage = "Unable to open PDF"
            loading = false
            return
        }

        pdfDocument = document
        loading = false
    }
}

// MARK: - PDFKit Wrapper

struct PDFKitRepresentedView: UIViewRepresentable {
    let document: PDFDocument

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.document = document
        return pdfView
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        uiView.document = document
    }
}
