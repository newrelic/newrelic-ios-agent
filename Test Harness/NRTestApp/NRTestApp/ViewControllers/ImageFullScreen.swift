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
        ImageDetailPDFView(image: image)
        .NRTrackView(name: "ImageDetailPDFView")
    }
}
