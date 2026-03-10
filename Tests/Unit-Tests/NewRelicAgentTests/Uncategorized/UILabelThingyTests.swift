import Foundation
import XCTest

class UILabelThingyTests: XCTestCase {
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

    func testInitWithUILabelMasked() {
        let label = UILabel()
        label.text = "SecretText"
        let details = makeViewDetails(isMasked: true)
        let thingy = UILabelThingy(view: label, viewDetails: details)
        XCTAssertEqual(thingy.labelText, String(repeating: "*", count: label.text!.count))
        XCTAssertTrue(thingy.isMasked)
    }

    func testInitWithUILabelUnmasked() {
        let label = UILabel()
        label.text = "VisibleText"
        let details = makeViewDetails(isMasked: false)
        let thingy = UILabelThingy(view: label, viewDetails: details)
        XCTAssertEqual(thingy.labelText, label.text)
        XCTAssertFalse(thingy.isMasked)
    }

    func testInitWithViewDetailsMasked() {
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
        XCTAssertEqual(thingy.labelText, "***")
        XCTAssertTrue(thingy.isMasked)
        XCTAssertEqual(thingy.fontSize, 15)
        XCTAssertEqual(thingy.textColor, color)
        XCTAssertEqual(thingy.textAlignment, "center")
    }

    func testInitWithViewDetailsUnmasked() {
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
        XCTAssertEqual(thingy.labelText, "abc")
        XCTAssertFalse(thingy.isMasked)
        XCTAssertEqual(thingy.fontSize, 15)
        XCTAssertEqual(thingy.textColor, color)
        XCTAssertEqual(thingy.textAlignment, "center")
    }

    func testExtractLabelAttributes_withAttributedText() {
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
        XCTAssertEqual(text, "Hello")
        XCTAssertEqual(extractedFont.fontName, font.fontName)
        XCTAssertEqual(extractedFont.pointSize, font.pointSize)
        XCTAssertEqual(extractedColor, color)
        XCTAssertEqual(extractedAlignment, "center")
        XCTAssertEqual(extractedLineBreakMode, .byWordWrapping)
    }
    
    func testExtractLabelAttributes_withEmptyAttributedText() {
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
        XCTAssertEqual(text, "")
    }

    func testInitWithAttributedTextMasked() {
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
        XCTAssertEqual(thingy.labelText, String(repeating: "*", count: attrString.string.count))
        XCTAssertTrue(thingy.isMasked)
        XCTAssertEqual(thingy.fontSize, 15)
        XCTAssertEqual(thingy.textColor, color)
        XCTAssertEqual(thingy.textAlignment, "center")
    }

    func testInitWithAttributedTextUnmasked() {
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
        XCTAssertEqual(thingy.labelText, "VisibleText")
        XCTAssertFalse(thingy.isMasked)
        XCTAssertEqual(thingy.fontSize, 15)
        XCTAssertEqual(thingy.textColor, color)
        XCTAssertEqual(thingy.textAlignment, "right")
    }

    func testInitWithAttributedTextEmpty() {
        let attrString = NSAttributedString(string: "")
        let details = makeViewDetails(isMasked: false)
        let thingy = UILabelThingy(viewDetails: details, attributedText: attrString)
        XCTAssertEqual(thingy.labelText, "")
        XCTAssertFalse(thingy.isMasked)
    }

    // MARK: - Word Wrap Tests

    func testUILabelWithNumberOfLines() {
        let label = UILabel()
        label.text = "Test text"
        label.numberOfLines = 2
        label.lineBreakMode = .byWordWrapping
        let details = makeViewDetails(isMasked: false)
        let thingy = UILabelThingy(view: label, viewDetails: details)
        XCTAssertEqual(thingy.numberOfLines, 2)
        XCTAssertEqual(thingy.lineBreakMode, .byWordWrapping)
    }

    func testUILabelSingleLine() {
        let label = UILabel()
        label.text = "Test text"
        label.numberOfLines = 1
        label.lineBreakMode = .byTruncatingTail
        let details = makeViewDetails(isMasked: false)
        let thingy = UILabelThingy(view: label, viewDetails: details)
        XCTAssertEqual(thingy.numberOfLines, 1)
        XCTAssertEqual(thingy.lineBreakMode, .byTruncatingTail)
        let css = thingy.inlineCSSDescription()
        XCTAssertTrue(css.contains("white-space: nowrap"))
        XCTAssertTrue(css.contains("text-overflow: ellipsis"))
    }

    func testUILabelMultilineWordWrapping() {
        let label = UILabel()
        label.text = "Test text with word wrapping"
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        let details = makeViewDetails(isMasked: false)
        let thingy = UILabelThingy(view: label, viewDetails: details)
        XCTAssertEqual(thingy.numberOfLines, 0)
        XCTAssertEqual(thingy.lineBreakMode, .byWordWrapping)
        let css = thingy.inlineCSSDescription()
        XCTAssertTrue(css.contains("white-space: pre-wrap"))
        XCTAssertTrue(css.contains("word-wrap: break-word"))
    }

    func testUILabelCharWrapping() {
        let label = UILabel()
        label.text = "Test text"
        label.numberOfLines = 0
        label.lineBreakMode = .byCharWrapping
        let details = makeViewDetails(isMasked: false)
        let thingy = UILabelThingy(view: label, viewDetails: details)
        XCTAssertEqual(thingy.lineBreakMode, .byCharWrapping)
        let css = thingy.inlineCSSDescription()
        XCTAssertTrue(css.contains("word-break: break-all"))
    }

    func testUILabelClipping() {
        let label = UILabel()
        label.text = "Test text"
        label.numberOfLines = 0
        label.lineBreakMode = .byClipping
        let details = makeViewDetails(isMasked: false)
        let thingy = UILabelThingy(view: label, viewDetails: details)
        XCTAssertEqual(thingy.lineBreakMode, .byClipping)
        let css = thingy.inlineCSSDescription()
        XCTAssertTrue(css.contains("overflow: hidden"))
        XCTAssertTrue(css.contains("white-space: nowrap"))
    }

    func testAttributedTextLineBreakMode() {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .left
        paragraph.lineBreakMode = .byCharWrapping
        let attrString = NSAttributedString(string: "Test", attributes: [
            .paragraphStyle: paragraph
        ])
        let details = makeViewDetails(isMasked: false)
        let thingy = UILabelThingy(viewDetails: details, attributedText: attrString)
        XCTAssertEqual(thingy.lineBreakMode, .byCharWrapping)
        XCTAssertEqual(thingy.numberOfLines, 0) // SwiftUI defaults to multiline
    }

    func testMultilineTruncation() {
        let label = UILabel()
        label.text = "Test text with truncation"
        label.numberOfLines = 3
        label.lineBreakMode = .byTruncatingTail
        let details = makeViewDetails(isMasked: false)
        let thingy = UILabelThingy(view: label, viewDetails: details)
        XCTAssertEqual(thingy.numberOfLines, 3)
        XCTAssertEqual(thingy.lineBreakMode, .byTruncatingTail)
        let css = thingy.inlineCSSDescription()
        XCTAssertTrue(css.contains("-webkit-line-clamp: 3"))
        XCTAssertTrue(css.contains("display: -webkit-box"))
    }

    // MARK: - Font Traits Tests

    func testBoldFont() {
        let label = UILabel()
        label.text = "Bold text"
        label.font = UIFont.boldSystemFont(ofSize: 17)
        let details = makeViewDetails(isMasked: false)
        let thingy = UILabelThingy(view: label, viewDetails: details)
        XCTAssertEqual(thingy.fontWeight, .bold)
        let css = thingy.inlineCSSDescription()
        XCTAssertTrue(css.contains("700"))
    }

    func testRegularFont() {
        let label = UILabel()
        label.text = "Regular text"
        label.font = UIFont.systemFont(ofSize: 17)
        let details = makeViewDetails(isMasked: false)
        let thingy = UILabelThingy(view: label, viewDetails: details)
        XCTAssertEqual(thingy.fontWeight, .regular)
        let css = thingy.inlineCSSDescription()
        XCTAssertTrue(css.contains("400"))
    }

    func testItalicFont() {
        let label = UILabel()
        label.text = "Italic text"
        label.font = UIFont.italicSystemFont(ofSize: 17)
        let details = makeViewDetails(isMasked: false)
        let thingy = UILabelThingy(view: label, viewDetails: details)
        XCTAssertTrue(thingy.isItalic)
        let css = thingy.inlineCSSDescription()
        XCTAssertTrue(css.contains("italic"))
    }

    func testLightFont() {
        let lightFont = UIFont.systemFont(ofSize: 17, weight: .light)
        let label = UILabel()
        label.text = "Light text"
        label.font = lightFont
        let details = makeViewDetails(isMasked: false)
        let thingy = UILabelThingy(view: label, viewDetails: details)
        XCTAssertEqual(thingy.fontWeight, .light)
        let css = thingy.inlineCSSDescription()
        XCTAssertTrue(css.contains("200"))
    }

    func testHeavyFont() {
        let heavyFont = UIFont.systemFont(ofSize: 17, weight: .heavy)
        let label = UILabel()
        label.text = "Heavy text"
        label.font = heavyFont
        let details = makeViewDetails(isMasked: false)
        let thingy = UILabelThingy(view: label, viewDetails: details)
        XCTAssertEqual(thingy.fontWeight, .bold)
        let css = thingy.inlineCSSDescription()
        XCTAssertTrue(css.contains("700"))
    }

    func testExtractFontTraitsBold() {
        let boldFont = UIFont.boldSystemFont(ofSize: 17)
        let (weight, isItalic) = TextHelper.extractFontTraits(from: boldFont)
        XCTAssertEqual(weight, .bold)
        XCTAssertFalse(isItalic)
    }

    func testExtractFontTraitsItalic() {
        let italicFont = UIFont.italicSystemFont(ofSize: 17)
        let (_, isItalic) = TextHelper.extractFontTraits(from: italicFont)
        XCTAssertTrue(isItalic)
    }

    func testExtractFontTraitsRegular() {
        let regularFont = UIFont.systemFont(ofSize: 17)
        let (weight, isItalic) = TextHelper.extractFontTraits(from: regularFont)
        XCTAssertEqual(weight, .regular)
        XCTAssertFalse(isItalic)
    }

    func testAttributedTextWithBoldFont() {
        let boldFont = UIFont.boldSystemFont(ofSize: 17)
        let attrString = NSAttributedString(string: "Bold", attributes: [.font: boldFont])
        let details = makeViewDetails(isMasked: false)
        let thingy = UILabelThingy(viewDetails: details, attributedText: attrString)
        XCTAssertEqual(thingy.fontWeight, .bold)
        XCTAssertFalse(thingy.isItalic)
    }

    func testAttributedTextWithItalicFont() {
        let italicFont = UIFont.italicSystemFont(ofSize: 17)
        let attrString = NSAttributedString(string: "Italic", attributes: [.font: italicFont])
        let details = makeViewDetails(isMasked: false)
        let thingy = UILabelThingy(viewDetails: details, attributedText: attrString)
        XCTAssertTrue(thingy.isItalic)
    }
}
