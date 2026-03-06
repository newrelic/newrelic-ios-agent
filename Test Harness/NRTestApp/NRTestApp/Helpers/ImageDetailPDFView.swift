//
//  ImageDetailView.swift
//  NRTestApp
//
//  Created by Mike Bruin on 2/28/23.
//

import SwiftUI
import PDFKit
import NewRelic

// A really quick way to get a better look at the space image
struct ImageDetailPDFView: UIViewRepresentable {
    
    let image: UIImage

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        
        // Validate the image before attempting to create a PDF
        guard image.cgImage != nil || image.ciImage != nil else {
            NewRelic.logWarning("Warning: Invalid UIImage - no backing CGImage or CIImage")
            view.document = PDFDocument()
            return view
        }
        
        // Create a new PDF document
        let pdfDocument = PDFDocument()
        
        // Attempt to create a PDF page from the image with error handling
        if let page = PDFPage(image: image) {
            pdfDocument.insert(page, at: 0)
        } else {
            NewRelic.logWarning("Warning: Failed to create PDFPage from UIImage")
        }
        
        view.document = pdfDocument
        view.autoScales = true
        view.backgroundColor = .clear
        return view
    }
    
    func updateUIView(_ uiView: PDFView, context: Context) {}
}
