//
//  UIImage+PngData.swift
//  Agent
//
//  Created by Mike Bruin on 12/11/25.
//  Copyright © 2025 New Relic. All rights reserved.
//

import UIKit

fileprivate var associatedOptimizedImageDataKey: String = "SessionReplayOptimizedImageData"

internal extension UIImage {
    private var cachedOptimizedData: Data? {
        set {
            withUnsafePointer(to: &associatedOptimizedImageDataKey) {
                objc_setAssociatedObject(self, $0, newValue, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            }
        }
        
        get {
            withUnsafePointer(to: &associatedOptimizedImageDataKey) {
                objc_getAssociatedObject(self, $0) as? Data
            }
        }
    }
    
    func optimizedPngData(maxDimension: CGFloat = 25) -> Data? {
        // Return cached data if available
        if let cachedData = cachedOptimizedData {
            return cachedData
        }
        
        let optimizedData = generateOptimizedPngData(maxDimension: maxDimension)
        cachedOptimizedData = optimizedData
        return optimizedData
    }
    
    private func generateOptimizedPngData(maxDimension: CGFloat) -> Data? {
        let originalSize = self.size

        // Calculate new size maintaining aspect ratio
        let scale: CGFloat
        if originalSize.width > originalSize.height {
            scale = min(1.0, maxDimension / originalSize.width)
        } else {
            scale = min(1.0, maxDimension / originalSize.height)
        }

        let newSize = CGSize(width: originalSize.width * scale, height: originalSize.height * scale)

        // Prevent zero size crash
        guard newSize.width > 0, newSize.height > 0 else {
            return nil
        }

        UIGraphicsBeginImageContextWithOptions(newSize, false, 0.0)
        defer { UIGraphicsEndImageContext() }

        draw(in: CGRect(origin: .zero, size: newSize))
        guard let resizedImage = UIGraphicsGetImageFromCurrentImageContext() else {
            return nil
        }

        return resizedImage.pngData()
    }
}
