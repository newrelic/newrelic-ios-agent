import Foundation
import Testing
import UIKit

// Stand-ins for the React Native classes ReactNativeStyle looks up by name, with the
// same Objective-C property names. React Native isn't linked into the tests.

@objc(RCTView)
private class FakePaperView: UIView {
    @objc var borderWidth: CGFloat = -1
    @objc var borderTopWidth: CGFloat = -1
    @objc var borderRightWidth: CGFloat = -1
    @objc var borderBottomWidth: CGFloat = -1
    @objc var borderLeftWidth: CGFloat = -1
    @objc var borderColor: UIColor?
    @objc var borderBottomColor: UIColor?
    @objc var borderRadius: CGFloat = -1
    @objc var borderTopLeftRadius: CGFloat = -1

    /// RCTView only draws its border into layer.contents when it can't use the CALayer
    /// border properties.
    func drawBorderIntoContents() {
        layer.contents = UIGraphicsImageRenderer(size: CGSize(width: 3, height: 3)).image { _ in }.cgImage
    }
}

@objc(RCTViewComponentView)
private class FakeFabricView: UIView {}

@objc(RNSVGSvgView)
private class FakeSVGView: UIView {
    var fill = UIColor.red {
        didSet { display() }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        display()
    }

    required init?(coder: NSCoder) { fatalError() }

    /// On screen, UIKit has already drawn the view into its layer by capture time.
    func display() {
        setNeedsDisplay()
        layer.displayIfNeeded()
    }

    override func draw(_ rect: CGRect) {
        fill.setFill()
        UIBezierPath(ovalIn: bounds).fill()
    }
}

@MainActor
struct ReactNativeStyleTests {

    // MARK: Old architecture borders

    @Test func `Paper bottom border is recorded on its edge only`() throws {
        let view = FakePaperView(frame: CGRect(x: 0, y: 0, width: 200, height: 50))
        view.borderBottomWidth = 0.5
        view.borderBottomColor = .gray
        view.drawBorderIntoContents()

        let style = try #require(ReactNativeStyle.borderStyle(for: view))
        let css = style.cssDescription()

        #expect(css.contains("border-bottom: 0.50px solid"))
        #expect(!css.contains("border-top:"))
        #expect(style.cornerRadii == nil)
    }

    @Test func `Paper rounded outline keeps its radius and border`() throws {
        let view = FakePaperView(frame: CGRect(x: 0, y: 0, width: 80, height: 32))
        view.borderRadius = 16
        view.borderTopLeftRadius = 4
        view.borderWidth = 1
        view.borderColor = .black
        view.drawBorderIntoContents()

        let style = try #require(ReactNativeStyle.borderStyle(for: view))

        #expect(style.cornerRadii == [4, 16, 16, 16])
        #expect(style.edges?.map(\.width) == [1, 1, 1, 1])
        #expect(style.cssDescription().contains("border-radius: 4.00px 16.00px 16.00px 16.00px;"))
    }

    @Test func `Paper border without a color draws nothing`() {
        let view = FakePaperView(frame: CGRect(x: 0, y: 0, width: 80, height: 32))
        view.borderWidth = 2
        view.borderColor = .clear
        view.drawBorderIntoContents()

        #expect(ReactNativeStyle.borderStyle(for: view) == nil)
    }

    @Test func `Paper view using CALayer borders is left to the layer properties`() {
        let view = FakePaperView(frame: CGRect(x: 0, y: 0, width: 80, height: 32))
        view.borderWidth = 1
        view.borderColor = .black
        view.layer.borderWidth = 1

        #expect(ReactNativeStyle.borderStyle(for: view) == nil)
    }

    // MARK: New Architecture borders

    @Test func `Fabric border bitmap becomes a border-image`() throws {
        let view = FakeFabricView(frame: CGRect(x: 0, y: 0, width: 80, height: 40))
        let backgroundLayer = CALayer()
        backgroundLayer.zPosition = ReactNativeStyle.fabricBackgroundLayerZPosition
        backgroundLayer.cornerRadius = 8
        let borderLayer = CALayer()
        borderLayer.zPosition = ReactNativeStyle.fabricBorderLayerZPosition
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        // A 5x5pt stretchable border: 2pt caps around a 1pt center.
        borderLayer.contents = UIGraphicsImageRenderer(size: CGSize(width: 5, height: 5), format: format).image { _ in }.cgImage
        borderLayer.contentsScale = 2
        borderLayer.contentsCenter = CGRect(x: 0.4, y: 0.4, width: 0.2, height: 0.2)
        view.layer.addSublayer(backgroundLayer)
        view.layer.addSublayer(borderLayer)

        let style = try #require(ReactNativeStyle.borderStyle(for: view))
        let borderImage = try #require(style.borderImage)

        #expect(borderImage.isResizable)
        #expect(borderImage.slice == [4, 4, 4, 4])
        #expect(borderImage.widths == [2, 2, 2, 2])
        #expect(borderImage.dataURL.hasPrefix("data:image/png;base64,"))
        #expect(style.cornerRadii == [8, 8, 8, 8])
        #expect(style.cssDescription().contains("border-image: url('data:image/png;base64,"))
    }

    @Test func `Fabric view without border layers has no style`() {
        #expect(ReactNativeStyle.borderStyle(for: FakeFabricView(frame: CGRect(x: 0, y: 0, width: 10, height: 10))) == nil)
    }

    // MARK: SVG

    @Test func `SVG view is rendered at its size`() throws {
        let view = FakeSVGView(frame: CGRect(x: 0, y: 0, width: 24, height: 24))

        let image = try #require(ReactNativeStyle.renderedImage(of: view))

        #expect(image.size == CGSize(width: 24, height: 24))
        #expect(ReactNativeStyle.isSVGView(view))
    }

    @Test func `Unchanged SVG reuses its previous image`() throws {
        let view = FakeSVGView(frame: CGRect(x: 0, y: 0, width: 24, height: 24))

        let first = try #require(ReactNativeStyle.renderedImage(of: view))
        let second = try #require(ReactNativeStyle.renderedImage(of: view))
        view.fill = .blue
        let third = try #require(ReactNativeStyle.renderedImage(of: view))

        #expect(first === second)
        #expect(first !== third)
    }

    func unmaskedDetails() -> ViewDetails {
        var details = ViewDetails(frame: CGRect(x: 0, y: 0, width: 24, height: 24), clip: CGRect(x: 0, y: 0, width: 400, height: 800),
                                  backgroundColor: .clear, alpha: 1, isHidden: false, viewName: "UILabel", parentId: 0,
                                  cornerRadius: 0, borderWidth: 0, viewId: 42,
                                  maskApplicationText: nil, maskUserInputText: nil, maskAllImages: nil, maskAllUserTouches: nil,
                                  blockView: nil, sessionReplayIdentifier: nil, isDefaultMaskingMode: false)
        details.isMasked = false
        return details
    }

    // MARK: Text

    @Test func `Strikethrough text gets a text decoration`() {
        let label = UILabel()
        label.attributedText = NSAttributedString(string: "$25.00", attributes: [.strikethroughStyle: NSUnderlineStyle.single.rawValue])

        let thingy = UILabelThingy(view: label, viewDetails: unmaskedDetails())

        #expect(thingy.textDecoration == "line-through")
        #expect(thingy.inlineCSSDescription().contains("text-decoration-line: line-through;"))
    }

    @Test func `Fabric text is placed inside its padding`() {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 400, height: 800))
        let paragraph = FabricParagraph.make()
        paragraph.frame = CGRect(x: 10, y: 20, width: 200, height: 40)
        let textView = UIView(frame: CGRect(x: 12, y: 4, width: 176, height: 32))
        paragraph.addSubview(textView)
        FabricParagraph.setContentView(textView, on: paragraph)
        window.addSubview(paragraph)

        var details = ViewDetails(view: paragraph)
        details.isMasked = false
        let thingy = UILabelThingy(view: paragraph, viewDetails: details)

        #expect(thingy.viewDetails.frame.origin == CGPoint(x: 22, y: 24))
        #expect(thingy.viewDetails.frame.size == CGSize(width: 177, height: 32))
    }
}

/// RCTParagraphComponentView with `attributedText` (as UILabelThingyTests builds it) plus
/// the `contentView` getter RCTViewComponentView has. Built at runtime because the class
/// may already exist from UILabelThingyTests, and either suite can run first.
private enum FabricParagraph {
    static var contentViewKey: UInt8 = 0

    static func make() -> UIView {
        let cls: AnyClass
        if let existing = NSClassFromString(RCTParagraphComponentView) {
            cls = existing
        } else {
            let newClass = objc_allocateClassPair(UIView.self, RCTParagraphComponentView, 0)!
            class_addIvar(newClass, "_attributedText", MemoryLayout<AnyObject>.size, UInt8(log2(Double(MemoryLayout<AnyObject>.alignment))), "@")
            let ivar = class_getInstanceVariable(newClass, "_attributedText")!
            let getter: @convention(block) (AnyObject) -> AnyObject? = { object_getIvar($0, ivar) as AnyObject? }
            class_addMethod(newClass, Selector("attributedText"), imp_implementationWithBlock(getter), "@@:")
            objc_registerClassPair(newClass)
            cls = newClass
        }
        let contentView: @convention(block) (AnyObject) -> AnyObject? = { object in
            withUnsafePointer(to: &contentViewKey) { objc_getAssociatedObject(object, $0) as AnyObject? }
        }
        class_addMethod(cls, Selector("contentView"), imp_implementationWithBlock(contentView), "@@:")
        return (cls as! UIView.Type).init(frame: .zero)
    }

    static func setContentView(_ contentView: UIView, on paragraph: UIView) {
        withUnsafePointer(to: &contentViewKey) {
            objc_setAssociatedObject(paragraph, $0, contentView, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
}
