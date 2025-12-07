//
//  PDFPageRenderer.swift
//  AIPanelSchedules
//
//  Created by Kenneth Riendeau on 12/7/25.
//
import PDFKit
import UIKit

struct PDFPageRenderer {

    static func renderSinglePage(from data: Data, scale: CGFloat = 3.0) -> UIImage? { // Increased scale to 3.0 for better OCR
        guard let pdf = PDFDocument(data: data),
              let page = pdf.page(at: 0) else { return nil }

        let pageRect = page.bounds(for: .mediaBox)
        
        // 1. Create the large scaled rectangle
        let scaledRect = CGRect(
            x: 0,
            y: 0,
            width: pageRect.width * scale,
            height: pageRect.height * scale
        )

        // 2. Begin context with the scaled size
        UIGraphicsBeginImageContextWithOptions(scaledRect.size, false, 1.0)
        
        guard let context = UIGraphicsGetCurrentContext() else {
            UIGraphicsEndImageContext()
            return nil
        }

        // 3. Set the background to white (PDFs are transparent by default)
        // If we don't do this, transparent areas might appear black/empty to Gemini
        context.setFillColor(UIColor.white.cgColor)
        context.fill(scaledRect)

        context.saveGState()

        // 4. Flip the coordinate system (Standard PDF adjustment)
        context.translateBy(x: 0, y: scaledRect.height)
        context.scaleBy(x: 1.0, y: -1.0)
        
        // 5. CRITICAL MISSING STEP: Apply the Zoom Scale!
        // Without this, the PDF draws at 1x size inside your 3x canvas.
        context.scaleBy(x: scale, y: scale)

        // 6. Draw the page
        context.drawPDFPage(page.pageRef!)
        context.restoreGState()

        let rendered = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return rendered
    }

}
