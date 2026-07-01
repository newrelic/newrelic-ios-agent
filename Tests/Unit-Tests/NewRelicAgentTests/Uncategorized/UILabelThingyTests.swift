import Foundation
import Testing
import UIKit

struct UILabelThingyTests {
    func makeViewDetails(isMasked: Bool? = nil) -> ViewDetails {
        // Provide a minimal ViewDetails stub for testing
        return ViewDetails(
            frame: .zero,
            clip: .zero,
            backgroundColor: .clear,
            alpha: 1.0,
            isHidden: false,
            viewName: "UILabel",
            parentId: 0, // Use 0 for no parent
            cornerRadius: 0,
            borderWidth: 0,
            borderColor: nil,
            viewId: 1,
            view: nil,
            maskApplicationText: isMasked,
            maskUserInputText: nil,
            maskAllImages: nil,
            maskAllUserTouches: nil, blockView: nil,
            sessionReplayIdentifier: nil
        )
    }

    @Test func `Init with UILabel masked`() {
        let label = UILabel()
        label.text = "SecretText"
        let details = makeViewDetails(isMasked: true)
        let thingy = UILabelThingy(view: label, viewDetails: details)
        #expect(thingy.labelText == String(repeating: "*", count: label.text!.count))
        #expect(thingy.isMasked)
    }

    @Test func `Init with UILabel unmasked`() {
        let label = UILabel()
        label.text = "VisibleText"
        let details = makeViewDetails(isMasked: false)
        let thingy = UILabelThingy(view: label, viewDetails: details)
        #expect(thingy.labelText == label.text)
        #expect(!thingy.isMasked)
    }

    @Test func `Init with view details masked`() {
        let details = makeViewDetails(isMasked: true)
        let font = UIFont(name: "Arial", size: 15) ?? UIFont.systemFont(ofSize: 15)
        let color = UIColor.red
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let attrString = NSAttributedString(string: "abc", attributes: [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraph
        ])
        let thingy = UILabelThingy(viewDetails: details, attributedText: attrString)
        #expect(thingy.labelText == "***")
        #expect(thingy.isMasked)
        #expect(thingy.fontSize == 15)
        #expect(thingy.textColor == color)
        #expect(thingy.textAlignment == "center")
    }

    @Test func `Init with view details unmasked`() {
        let details = makeViewDetails(isMasked: false)
        let font = UIFont(name: "Arial", size: 15) ?? UIFont.systemFont(ofSize: 15)
        let color = UIColor.black
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let attrString = NSAttributedString(string: "abc", attributes: [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraph
        ])
        let thingy = UILabelThingy(viewDetails: details, attributedText: attrString)
        #expect(thingy.labelText == "abc")
        #expect(!thingy.isMasked)
        #expect(thingy.fontSize == 15)
        #expect(thingy.textColor == color)
        #expect(thingy.textAlignment == "center")
    }

    // MARK: - Default masking strategy guard (SwiftUI / NRConditionalMaskView)

    private func makeSwiftUIViewDetails(maskApplicationText: Bool? = nil,
                                        maskUserInputText: Bool? = nil,
                                        maskAllImages: Bool? = nil,
                                        maskAllUserTouches: Bool? = nil,
                                        isDefaultMaskingMode: Bool) -> ViewDetails {
        return ViewDetails(
            frame: .zero,
            clip: .zero,
            backgroundColor: .clear,
            alpha: 1.0,
            isHidden: false,
            viewName: "UILabel",
            parentId: 0,
            cornerRadius: 0,
            borderWidth: 0,
            borderColor: nil,
            viewId: 1,
            view: nil,
            maskApplicationText: maskApplicationText,
            maskUserInputText: maskUserInputText,
            maskAllImages: maskAllImages,
            maskAllUserTouches: maskAllUserTouches,
            blockView: nil,
            sessionReplayIdentifier: nil,
            isDefaultMaskingMode: isDefaultMaskingMode
        )
    }

    // Under the Default strategy, an NRConditionalMaskView(maskApplicationText: false)
    // unmask override must be dropped so the global default (mask) governs.
    @Test func `Default strategy drops unmask text override`() {
        let details = makeSwiftUIViewDetails(maskApplicationText: false, isDefaultMaskingMode: true)
        #expect(details.maskApplicationText == nil)
    }

    // Custom strategy continues to honor the unmask override (text visible).
    @Test func `Custom strategy keeps unmask text override`() {
        let details = makeSwiftUIViewDetails(maskApplicationText: false, isDefaultMaskingMode: false)
        #expect(details.maskApplicationText == false)
    }

    // Overrides that *increase* masking (true) are still honored under Default.
    @Test func `Default strategy keeps mask true override`() {
        let details = makeSwiftUIViewDetails(maskApplicationText: true, isDefaultMaskingMode: true)
        #expect(details.maskApplicationText == true)
    }

    // The guard applies to every unmask-capable override field under Default.
    @Test func `Default strategy drops all unmask overrides`() {
        let details = makeSwiftUIViewDetails(maskApplicationText: false,
                                             maskUserInputText: false,
                                             maskAllImages: false,
                                             maskAllUserTouches: false,
                                             isDefaultMaskingMode: true)
        #expect(details.maskApplicationText == nil)
        #expect(details.maskUserInputText == nil)
        #expect(details.maskAllImages == nil)
        #expect(details.maskAllUserTouches == nil)
    }

    // End-to-end: a SwiftUI label that tried to unmask itself stays masked (asterisks)
    // under the Default strategy.
    @Test func `Default strategy masks label despite unmask override`() {
        let label = UILabel()
        label.text = "SecretText"
        let details = makeSwiftUIViewDetails(maskApplicationText: false, isDefaultMaskingMode: true)
        let thingy = UILabelThingy(view: label, viewDetails: details)
        #expect(thingy.isMasked)
        #expect(thingy.labelText == String(repeating: "*", count: label.text!.count))
    }

    // MARK: - Default masking strategy guard (UIKit direct sets)

    // A UIKit view that tried to unmask itself via a direct `maskApplicationText =
    // false` set must have that override dropped under the Default strategy, so the
    // global default (mask) governs. This is the UIKit analogue of the SwiftUI guard.
    @Test func `UIKit direct-set unmask text override dropped under Default`() {
        let view = UIView()
        view.maskApplicationText = false
        let overrides = ViewDetails.directSetMaskingOverrides(view: view, isDefaultMode: true)
        #expect(overrides.maskApplicationText == nil)
    }

    // The guard covers every unmask-capable direct-set field under Default.
    @Test func `UIKit direct-set drops all unmask overrides under Default`() {
        let view = UIView()
        view.maskApplicationText = false
        view.maskUserInputText = false
        view.maskAllImages = false
        view.maskAllUserTouches = false
        let overrides = ViewDetails.directSetMaskingOverrides(view: view, isDefaultMode: true)
        #expect(overrides.maskApplicationText == nil)
        #expect(overrides.maskUserInputText == nil)
        #expect(overrides.maskAllImages == nil)
        #expect(overrides.maskAllUserTouches == nil)
    }

    // Custom strategy continues to honor a direct-set unmask override.
    @Test func `UIKit direct-set unmask override honored under Custom`() {
        let view = UIView()
        view.maskApplicationText = false
        view.maskAllImages = false
        let overrides = ViewDetails.directSetMaskingOverrides(view: view, isDefaultMode: false)
        #expect(overrides.maskApplicationText == false)
        #expect(overrides.maskAllImages == false)
    }

    // Overrides that *increase* masking (true) are still honored under Default.
    @Test func `UIKit direct-set mask true override honored under Default`() {
        let view = UIView()
        view.maskAllImages = true
        view.maskApplicationText = true
        let overrides = ViewDetails.directSetMaskingOverrides(view: view, isDefaultMode: true)
        #expect(overrides.maskAllImages == true)
        #expect(overrides.maskApplicationText == true)
    }

    // A direct-set unmask on an ancestor is inherited by the child and likewise
    // dropped under Default (checkMask* walks the superview chain).
    @Test func `UIKit inherited unmask override dropped under Default`() {
        let parent = UIView()
        parent.maskAllImages = false
        let child = UIView()
        parent.addSubview(child)
        let overrides = ViewDetails.directSetMaskingOverrides(view: child, isDefaultMode: true)
        #expect(overrides.maskAllImages == nil)
    }

    // End-to-end: a masked ViewDetails (as produced when the guard forces masking)
    // renders a UILabel's text as asterisks.
    @Test func `Masked view details renders label as asterisks`() {
        let label = UILabel()
        label.text = "SecretText"
        let details = makeViewDetails(isMasked: true)
        let thingy = UILabelThingy(view: label, viewDetails: details)
        #expect(thingy.isMasked)
        #expect(thingy.labelText == String(repeating: "*", count: label.text!.count))
    }

    @Test func `Extract label attributes with attributed text`() {
        let font = UIFont(name: "Arial", size: 15) ?? UIFont.systemFont(ofSize: 15)
        let color = UIColor.red
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineBreakMode = .byWordWrapping
        let attrString = NSAttributedString(string: "Hello", attributes: [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraph
        ])
        let (text, extractedFont, extractedColor, extractedAlignment, extractedLineBreakMode, _) = TextHelper.extractLabelAttributes(from: attrString)
        #expect(text == "Hello")
        #expect(extractedFont.fontName == font.fontName)
        #expect(extractedFont.pointSize == font.pointSize)
        #expect(extractedColor == color)
        #expect(extractedAlignment == "center")
        #expect(extractedLineBreakMode == .byWordWrapping)
    }

    @Test func `Extract label attributes with empty attributed text`() {
        let font = UIFont(name: "Arial", size: 15) ?? UIFont.systemFont(ofSize: 15)
        let color = UIColor.red
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let attrString = NSAttributedString(string: "", attributes: [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraph
        ])
        let (text, _, _, _, _, _) = TextHelper.extractLabelAttributes(from: attrString)
        #expect(text == "")
    }

    @Test func `Init with attributed text masked`() {
        let font = UIFont(name: "Arial", size: 15) ?? UIFont.systemFont(ofSize: 15)
        let color = UIColor.black
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let attrString = NSAttributedString(string: "SecretText", attributes: [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraph
        ])
        let details = makeViewDetails(isMasked: true)
        let thingy = UILabelThingy(viewDetails: details, attributedText: attrString)
        #expect(thingy.labelText == String(repeating: "*", count: attrString.string.count))
        #expect(thingy.isMasked)
        #expect(thingy.fontSize == 15)
        #expect(thingy.textColor == color)
        #expect(thingy.textAlignment == "center")
    }

    @Test func `Init with attributed text unmasked`() {
        let font = UIFont(name: "Arial", size: 15) ?? UIFont.systemFont(ofSize: 15)
        let color = UIColor.blue
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .right
        let attrString = NSAttributedString(string: "VisibleText", attributes: [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraph
        ])
        let details = makeViewDetails(isMasked: false)
        let thingy = UILabelThingy(viewDetails: details, attributedText: attrString)
        #expect(thingy.labelText == "VisibleText")
        #expect(!thingy.isMasked)
        #expect(thingy.fontSize == 15)
        #expect(thingy.textColor == color)
        #expect(thingy.textAlignment == "right")
    }

    @Test func `Init with attributed text empty`() {
        let attrString = NSAttributedString(string: "")
        let details = makeViewDetails(isMasked: false)
        let thingy = UILabelThingy(viewDetails: details, attributedText: attrString)
        #expect(thingy.labelText == "")
        #expect(!thingy.isMasked)
    }

    // MARK: - Word Wrap Tests

    @Test func `UILabel with number of lines`() {
        let label = UILabel()
        label.text = "Test text"
        label.numberOfLines = 2
        label.lineBreakMode = .byWordWrapping
        let details = makeViewDetails(isMasked: false)
        let thingy = UILabelThingy(view: label, viewDetails: details)
        #expect(thingy.numberOfLines == 2)
        #expect(thingy.lineBreakMode == .byWordWrapping)
    }

    @Test func `UILabel single line`() {
        let label = UILabel()
        label.text = "Test text"
        label.numberOfLines = 1
        label.lineBreakMode = .byTruncatingTail
        let details = makeViewDetails(isMasked: false)
        let thingy = UILabelThingy(view: label, viewDetails: details)
        #expect(thingy.numberOfLines == 1)
        #expect(thingy.lineBreakMode == .byTruncatingTail)
        let css = thingy.inlineCSSDescription()
        #expect(css.contains("white-space: nowrap"))
        #expect(css.contains("text-overflow: ellipsis"))
    }

    @Test func `UILabel multiline word wrapping`() {
        let label = UILabel()
        label.text = "Test text with word wrapping"
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        let details = makeViewDetails(isMasked: false)
        let thingy = UILabelThingy(view: label, viewDetails: details)
        #expect(thingy.numberOfLines == 0)
        #expect(thingy.lineBreakMode == .byWordWrapping)
        let css = thingy.inlineCSSDescription()
        #expect(css.contains("white-space: pre-wrap"))
        #expect(css.contains("word-wrap: break-word"))
    }

    @Test func `UILabel char wrapping`() {
        let label = UILabel()
        label.text = "Test text"
        label.numberOfLines = 0
        label.lineBreakMode = .byCharWrapping
        let details = makeViewDetails(isMasked: false)
        let thingy = UILabelThingy(view: label, viewDetails: details)
        #expect(thingy.lineBreakMode == .byCharWrapping)
        let css = thingy.inlineCSSDescription()
        #expect(css.contains("word-break: break-all"))
    }

    @Test func `UILabel clipping`() {
        let label = UILabel()
        label.text = "Test text"
        label.numberOfLines = 0
        label.lineBreakMode = .byClipping
        let details = makeViewDetails(isMasked: false)
        let thingy = UILabelThingy(view: label, viewDetails: details)
        #expect(thingy.lineBreakMode == .byClipping)
        let css = thingy.inlineCSSDescription()
        #expect(css.contains("overflow: hidden"))
        #expect(css.contains("white-space: nowrap"))
    }

    @Test func `Attributed text line break mode`() {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .left
        paragraph.lineBreakMode = .byCharWrapping
        let attrString = NSAttributedString(string: "Test", attributes: [
            .paragraphStyle: paragraph
        ])
        let details = makeViewDetails(isMasked: false)
        let thingy = UILabelThingy(viewDetails: details, attributedText: attrString)
        #expect(thingy.lineBreakMode == .byCharWrapping)
        #expect(thingy.numberOfLines == 0) // SwiftUI defaults to multiline
    }

    @Test func `Multiline truncation`() {
        let label = UILabel()
        label.text = "Test text with truncation"
        label.numberOfLines = 3
        label.lineBreakMode = .byTruncatingTail
        let details = makeViewDetails(isMasked: false)
        let thingy = UILabelThingy(view: label, viewDetails: details)
        #expect(thingy.numberOfLines == 3)
        #expect(thingy.lineBreakMode == .byTruncatingTail)
        let css = thingy.inlineCSSDescription()
        #expect(css.contains("-webkit-line-clamp: 3"))
        #expect(css.contains("display: -webkit-box"))
    }

    // MARK: - Font Traits Tests

    @Test func `Bold font`() {
        let label = UILabel()
        label.text = "Bold text"
        label.font = UIFont.boldSystemFont(ofSize: 17)
        let details = makeViewDetails(isMasked: false)
        let thingy = UILabelThingy(view: label, viewDetails: details)
        #expect(thingy.fontWeight == .bold)
        let css = thingy.inlineCSSDescription()
        #expect(css.contains("700"))
    }

    @Test func `Regular font`() {
        let label = UILabel()
        label.text = "Regular text"
        label.font = UIFont.systemFont(ofSize: 17)
        let details = makeViewDetails(isMasked: false)
        let thingy = UILabelThingy(view: label, viewDetails: details)
        #expect(thingy.fontWeight == .regular)
        let css = thingy.inlineCSSDescription()
        #expect(css.contains("400"))
    }

    @Test func `Italic font`() {
        let label = UILabel()
        label.text = "Italic text"
        label.font = UIFont.italicSystemFont(ofSize: 17)
        let details = makeViewDetails(isMasked: false)
        let thingy = UILabelThingy(view: label, viewDetails: details)
        #expect(thingy.isItalic)
        let css = thingy.inlineCSSDescription()
        #expect(css.contains("italic"))
    }

    @Test func `Light font`() {
        let lightFont = UIFont.systemFont(ofSize: 17, weight: .light)
        let label = UILabel()
        label.text = "Light text"
        label.font = lightFont
        let details = makeViewDetails(isMasked: false)
        let thingy = UILabelThingy(view: label, viewDetails: details)
        #expect(thingy.fontWeight == .light)
        let css = thingy.inlineCSSDescription()
        #expect(css.contains("200"))
    }

    @Test func `Heavy font`() {
        let heavyFont = UIFont.systemFont(ofSize: 17, weight: .heavy)
        let label = UILabel()
        label.text = "Heavy text"
        label.font = heavyFont
        let details = makeViewDetails(isMasked: false)
        let thingy = UILabelThingy(view: label, viewDetails: details)
        #expect(thingy.fontWeight == .bold)
        let css = thingy.inlineCSSDescription()
        #expect(css.contains("700"))
    }

    @Test func `Extract font traits bold`() {
        let boldFont = UIFont.boldSystemFont(ofSize: 17)
        let (weight, isItalic) = TextHelper.extractFontTraits(from: boldFont)
        #expect(weight == .bold)
        #expect(!isItalic)
    }

    @Test func `Extract font traits italic`() {
        let italicFont = UIFont.italicSystemFont(ofSize: 17)
        let (_, isItalic) = TextHelper.extractFontTraits(from: italicFont)
        #expect(isItalic)
    }

    @Test func `Extract font traits regular`() {
        let regularFont = UIFont.systemFont(ofSize: 17)
        let (weight, isItalic) = TextHelper.extractFontTraits(from: regularFont)
        #expect(weight == .regular)
        #expect(!isItalic)
    }

    @Test func `Attributed text with bold font`() {
        let boldFont = UIFont.boldSystemFont(ofSize: 17)
        let attrString = NSAttributedString(string: "Bold", attributes: [.font: boldFont])
        let details = makeViewDetails(isMasked: false)
        let thingy = UILabelThingy(viewDetails: details, attributedText: attrString)
        #expect(thingy.fontWeight == .bold)
        #expect(!thingy.isItalic)
    }

    @Test func `Attributed text with italic font`() {
        let italicFont = UIFont.italicSystemFont(ofSize: 17)
        let attrString = NSAttributedString(string: "Italic", attributes: [.font: italicFont])
        let details = makeViewDetails(isMasked: false)
        let thingy = UILabelThingy(viewDetails: details, attributedText: attrString)
        #expect(thingy.isItalic)
    }
}
