//
//  ImageDetailView.swift
//  NRTestApp
//
//  Created by Mike Bruin on 2/28/23.
//

import SwiftUI
import PDFKit

// A really quick way to get a better look at the space image
struct ImageDetailPDFView: UIViewRepresentable {
    
    let image: UIImage

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.document = PDFDocument()
        guard let page = PDFPage(image: image) else { return view }
        view.document?.insert(page, at: 0)
        view.autoScales = true
        return view
    }
    
    func updateUIView(_ uiView: PDFView, context: Context) {}
}
