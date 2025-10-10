//
//  ImageFullScreen.swift
//  NRTestApp
//
//  Created by Mike Bruin on 2/28/23.
//

import SwiftUI

@available(iOS 14.0, *)
struct ImageFullScreen: View {
    let image: UIImage

    var body: some View {
        // Use a simple SwiftUI Image instead of PDF view to avoid CoreGraphics issues
        ScrollView([.horizontal, .vertical]) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .id("theImage")
        }
        .background(Color.black)
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("Image")
        .onAppear {
            let _ = ViewBodyTracker.track(self)  // ← At top level view
        }
        
    }
}
