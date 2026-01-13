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
        let thingy = UILabelThingy(viewDetails: details, text: "abc", textAlignment: "left", fontSize: 12, fontName: "Arial", fontFamily: "Arial", textColor: .black)
        XCTAssertEqual(thingy.labelText, "***")
        XCTAssertTrue(thingy.isMasked)
    }

    func testInitWithViewDetailsUnmasked() {
        let details = makeViewDetails(isMasked: false)
        let thingy = UILabelThingy(viewDetails: details, text: "abc", textAlignment: "left", fontSize: 12, fontName: "Arial", fontFamily: "Arial", textColor: .black)
        XCTAssertEqual(thingy.labelText, "abc")
        XCTAssertFalse(thingy.isMasked)
    }

    func testExtractLabelAttributes_withAttributedText() {
        // Create a UIView subclass that mimics a UILabel with attributedText
        class AttributedLabelView: UIView {
            let attributed: NSAttributedString
            init(attributed: NSAttributedString) {
                self.attributed = attributed
                super.init(frame: .zero)
            }
            required init?(coder: NSCoder) { fatalError() }
            override func value(forKey key: String) -> Any? {
                if key == "attributedText" { return attributed }
                return nil
            }
            override func responds(to aSelector: Selector!) -> Bool {
                if aSelector == Selector(("attributedText")) { return true }
                return super.responds(to: aSelector)
            }
        }
        let font = UIFont(name: "Arial", size: 15) ?? UIFont.systemFont(ofSize: 15)
        let color = UIColor.red
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let attrString = NSAttributedString(string: "Hello", attributes: [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraph
        ])
        let view = AttributedLabelView(attributed: attrString)
        let (text, extractedFont, extractedColor, extractedAlignment) = UILabelThingy.extractLabelAttributes(from: view)
        XCTAssertEqual(text, "Hello")
        XCTAssertEqual(extractedFont.fontName, font.fontName)
        XCTAssertEqual(extractedFont.pointSize, font.pointSize)
        XCTAssertEqual(extractedColor, color)
        XCTAssertEqual(extractedAlignment, "center")
    }
    
    func testExtractLabelAttributes_withEmptyAttributedText() {
        // Create a UIView subclass that mimics a UILabel with attributedText
        class AttributedLabelView: UIView {
            let attributed: NSAttributedString
            init(attributed: NSAttributedString) {
                self.attributed = attributed
                super.init(frame: .zero)
            }
            required init?(coder: NSCoder) { fatalError() }
            override func value(forKey key: String) -> Any? {
                if key == "attributedText" { return attributed }
                return nil
            }
            override func responds(to aSelector: Selector!) -> Bool {
                if aSelector == Selector(("attributedText")) { return true }
                return super.responds(to: aSelector)
            }
        }
        let font = UIFont(name: "Arial", size: 15) ?? UIFont.systemFont(ofSize: 15)
        let color = UIColor.red
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let attrString = NSAttributedString(string: "", attributes: [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraph
        ])
        let view = AttributedLabelView(attributed: attrString)
        let (text, _, _, _) = UILabelThingy.extractLabelAttributes(from: view)
        XCTAssertEqual(text, "")
    }
}
