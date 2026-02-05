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
            maskAllUserTouches: nil,
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
        let attrString = NSAttributedString(string: "Hello", attributes: [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraph
        ])
        let (text, extractedFont, extractedColor, extractedAlignment) = UILabelThingy.extractLabelAttributes(from: attrString)
        XCTAssertEqual(text, "Hello")
        XCTAssertEqual(extractedFont.fontName, font.fontName)
        XCTAssertEqual(extractedFont.pointSize, font.pointSize)
        XCTAssertEqual(extractedColor, color)
        XCTAssertEqual(extractedAlignment, "center")
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
        let (text, _, _, _) = UILabelThingy.extractLabelAttributes(from: attrString)
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
}
