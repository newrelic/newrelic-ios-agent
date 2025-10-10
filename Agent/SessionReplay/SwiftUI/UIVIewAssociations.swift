//
//  UIViewAssociations.swift
//  NRTestApp
//
//  Created by Chris Dillard on 10/10/25.
//

import Foundation
import UIKit
/*
 hostingController.view.masking.maskApplicationText
 hostingController.view.masking.maskUserInputText
 hostingController.view.masking.maskAllImages
 hostingController.view.masking.maskAllUserTouches
 */


internal var associatedMaskApplicationTextKey: UInt8 = 3
internal var associatedMaskUserInputTextKey: UInt8 = 4
internal var associatedMaskAllUserTouchesKey: UInt8 = 5
internal var associatedMaskAllImagesKey: UInt8 = 6


extension UIView {

    public var maskApplicationText: Bool? {
        
        set {
            withUnsafePointer(to: &associatedMaskApplicationTextKey) {
                objc_setAssociatedObject(self, $0, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

            }
        }
        
        
        get {
            withUnsafePointer(to: &associatedMaskApplicationTextKey) {
                objc_getAssociatedObject(self, $0) as? Bool
            }
        }
    }
    
    public var maskUserInputText: Bool? {
        
        set {
            withUnsafePointer(to: &associatedMaskUserInputTextKey) {
                objc_setAssociatedObject(self, $0, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

            }
        }
        
        
        get {
            withUnsafePointer(to: &associatedMaskUserInputTextKey) {
                objc_getAssociatedObject(self, $0) as? Bool
            }
        }
    }

    public var maskAllImages: Bool? {
        
        set {
            withUnsafePointer(to: &associatedMaskAllImagesKey) {
                objc_setAssociatedObject(self, $0, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

            }
        }
        
        
        get {
            withUnsafePointer(to: &associatedMaskAllImagesKey) {
                objc_getAssociatedObject(self, $0) as? Bool
            }
        }
    }
    
    public var maskAllUserTouches: Bool? {
        
        set {
            withUnsafePointer(to: &associatedMaskAllUserTouchesKey) {
                objc_setAssociatedObject(self, $0, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

            }
        }
        
        
        get {
            withUnsafePointer(to: &associatedMaskAllUserTouchesKey) {
                objc_getAssociatedObject(self, $0) as? Bool
            }
        }
    }
}
