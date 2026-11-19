import Foundation
import Testing
import UIKit

// Stand-ins for the React Native classes ReactNativeStyle looks up by name, with the
// same Objective-C property names. React Native isn't linked into the tests.

@objc(RCTView)
private class FakePaperView: UIView {
    @objc var reactLayoutDirection: UIUserInterfaceLayoutDirection = .leftToRight
    @objc var borderWidth: CGFloat = -1
    @objc var borderTopWidth: CGFloat = -1
    @objc var borderRightWidth: CGFloat = -1
    @objc var borderBottomWidth: CGFloat = -1
    @objc var borderLeftWidth: CGFloat = -1
    @objc var borderStartWidth: CGFloat = -1
    @objc var borderColor: UIColor?
    @objc var borderBottomColor: UIColor?
    @objc var borderLeftColor: UIColor?
    @objc var borderStartColor: UIColor?
    @objc var borderBlockColor: UIColor?
    @objc var borderStyle: Int = 0
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

    @Test func `Paper start border is drawn on the right in RTL`() throws {
        let view = FakePaperView(frame: CGRect(x: 0, y: 0, width: 80, height: 32))
        view.reactLayoutDirection = .rightToLeft
        view.borderStartWidth = 2
        view.borderColor = .black
        view.drawBorderIntoContents()

        let style = try #require(ReactNativeStyle.borderStyle(for: view))

        #expect(style.edges?.map(\.width) == [0, 2, 0, 0])
    }

    @Test func `Paper start color wins over left color`() throws {
        let view = FakePaperView(frame: CGRect(x: 0, y: 0, width: 80, height: 32))
        view.borderLeftWidth = 1
        view.borderLeftColor = .red
        view.borderStartColor = .blue
        view.drawBorderIntoContents()

        let style = try #require(ReactNativeStyle.borderStyle(for: view))

        #expect(style.edges?[3].color == UIColor.blue.toHexString(includingAlpha: true))
    }

    @Test func `Paper block color paints top and bottom`() throws {
        let view = FakePaperView(frame: CGRect(x: 0, y: 0, width: 80, height: 32))
        view.borderWidth = 1
        view.borderColor = .black
        view.borderBlockColor = .red
        view.drawBorderIntoContents()

        let colors = try #require(ReactNativeStyle.borderStyle(for: view)?.edges?.map(\.color))

        let red = UIColor.red.toHexString(includingAlpha: true), black = UIColor.black.toHexString(includingAlpha: true)
        #expect(colors == [red, black, red, black])
    }

    @Test func `Paper dashed border stays dashed`() throws {
        let view = FakePaperView(frame: CGRect(x: 0, y: 0, width: 80, height: 32))
        view.borderWidth = 1
        view.borderColor = .black
        view.borderStyle = 3 // RCTBorderStyleDashed
        view.drawBorderIntoContents()

        let style = try #require(ReactNativeStyle.borderStyle(for: view))

        #expect(style.cssDescription().contains("border-top: 1.00px dashed"))
    }

    @Test func `Paper radii too big for the view are scaled down like RCTView does`() throws {
        let view = FakePaperView(frame: CGRect(x: 0, y: 0, width: 80, height: 20))
        view.borderRadius = 20
        view.borderTopLeftRadius = 0
        view.drawBorderIntoContents()

        let style = try #require(ReactNativeStyle.borderStyle(for: view))

        // Each side fits its two corners: the 20pt height halves the right-hand ones.
        #expect(style.cornerRadii == [0, 10, 10, 20])
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
        // The bitmap goes in a stylesheet rule, not the inline style resent on every change.
        #expect(style.bitmapCSS?.contains("border-image: url('data:image/png;base64,") == true)
        #expect(!style.cssDescription().contains("data:image"))
        #expect(style.cssDescription().contains("border-width: 2.00px 2.00px 2.00px 2.00px;"))
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
        let paragraph = FabricParagraph.make(frame: CGRect(x: 10, y: 20, width: 200, height: 40),
                                             contentInsets: UIEdgeInsets(top: 4, left: 12, bottom: 4, right: 12))
        window.addSubview(paragraph)

        var details = ViewDetails(view: paragraph)
        details.isMasked = false
        let thingy = UILabelThingy(view: paragraph, viewDetails: details)

        // The box keeps its frame, for its background and border; only the text is inset.
        #expect(thingy.viewDetails.frame == CGRect(x: 10, y: 20, width: 201, height: 40))
        #expect(thingy.textPadding == [4, 12, 4, 12])
        #expect(thingy.inlineCSSDescription().contains("box-sizing: border-box; padding: 4.00px 12.00px 4.00px 12.00px;"))
    }

    @Test func `Text padding leaves room for the border the replay draws`() {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 400, height: 800))
        // RN's insets include the 2pt border.
        let paragraph = FabricParagraph.make(frame: CGRect(x: 0, y: 0, width: 100, height: 30),
                                             contentInsets: UIEdgeInsets(top: 6, left: 10, bottom: 6, right: 10))
        paragraph.layer.borderWidth = 2
        paragraph.layer.borderColor = UIColor.black.cgColor
        window.addSubview(paragraph)

        var details = ViewDetails(view: paragraph)
        details.isMasked = false
        let thingy = UILabelThingy(view: paragraph, viewDetails: details)

        #expect(thingy.inlineCSSDescription().contains("padding: 4.00px 8.00px 4.00px 8.00px;"))
    }

    @Test func `Fabric text without readable layout metrics keeps its frame`() {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 400, height: 800))
        // Laid out at 200x40, but the view has since been resized: the metrics are stale.
        let paragraph = FabricParagraph.make(frame: CGRect(x: 10, y: 20, width: 200, height: 40),
                                             contentInsets: UIEdgeInsets(top: 4, left: 12, bottom: 4, right: 12))
        paragraph.frame.size = CGSize(width: 300, height: 40)
        window.addSubview(paragraph)

        #expect(ReactNativeStyle.textContentFrame(of: paragraph) == nil)
    }
}

/// RCTParagraphComponentView with `attributedText` (as UILabelThingyTests builds it), and a
/// subclass with the C++ `_layoutMetrics` ivar RCTViewComponentView has, which can't be added
/// to a class that already exists. Built at runtime because the base class may already exist
/// from UILabelThingyTests, and either suite can run first.
private enum FabricParagraph {
    static let layoutMetricsEncoding = #"{LayoutMetrics="frame"{Rect="origin"{Point="x"d"y"d}"size"{Size="width"d"height"d}}"contentInsets"{RectangleEdges<double>="left"d"top"d"right"d"bottom"d}}"#

    static func make(frame: CGRect, contentInsets insets: UIEdgeInsets) -> UIView {
        let view = (paddedParagraphClass as! UIView.Type).init(frame: frame)
        let ivar = class_getInstanceVariable(paddedParagraphClass, "_layoutMetrics")!
        let layoutMetrics = UnsafeMutableRawPointer(Unmanaged.passUnretained(view).toOpaque()) + ivar_getOffset(ivar)
        for (index, value) in [frame.minX, frame.minY, frame.width, frame.height,
                               insets.left, insets.top, insets.right, insets.bottom].enumerated() {
            layoutMetrics.storeBytes(of: value, toByteOffset: index * MemoryLayout<CGFloat>.stride, as: CGFloat.self)
        }
        return view
    }

    static let paddedParagraphClass: AnyClass = {
        let name = "NRTestPaddedParagraphComponentView"
        if let existing = NSClassFromString(name) {
            return existing
        }
        let newClass = objc_allocateClassPair(paragraphClass, name, 0)!
        class_addIvar(newClass, "_layoutMetrics", 8 * MemoryLayout<CGFloat>.size,
                      UInt8(log2(Double(MemoryLayout<CGFloat>.alignment))), layoutMetricsEncoding)
        objc_registerClassPair(newClass)
        return newClass
    }()

    static var paragraphClass: AnyClass {
        if let existing = NSClassFromString(RCTParagraphComponentView) {
            return existing
        }
        let newClass = objc_allocateClassPair(UIView.self, RCTParagraphComponentView, 0)!
        class_addIvar(newClass, "_attributedText", MemoryLayout<AnyObject>.size, UInt8(log2(Double(MemoryLayout<AnyObject>.alignment))), "@")
        let ivar = class_getInstanceVariable(newClass, "_attributedText")!
        let getter: @convention(block) (AnyObject) -> AnyObject? = { object_getIvar($0, ivar) as AnyObject? }
        class_addMethod(newClass, Selector("attributedText"), imp_implementationWithBlock(getter), "@@:")
        objc_registerClassPair(newClass)
        return newClass
    }
}
