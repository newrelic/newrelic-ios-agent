//
//  MobileViewCompositionTests.swift
//  NewRelicAgent
//
//  containsWebView, isFullScreenWebView and isTopLevelView: how the schema writes them, and the
//  SwiftUI shapes of the two questions -- a WKWebView wrapped in a UIViewRepresentable, and SwiftUI
//  hosting controllers in a controller's parent chain.
//
//  Copyright © 2026 New Relic. All rights reserved.
//

import XCTest
import SwiftUI
import WebKit
@testable import NewRelic

private struct WebRepresentable: UIViewRepresentable {
    func makeUIView(context: Context) -> WKWebView { WKWebView(frame: .zero) }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

private struct WebScreen: View {
    var body: some View {
        WebRepresentable().frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct NativeScreen: View {
    var body: some View {
        VStack {
            Text("Checkout")
            Button("Pay") {}
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct BannerScreen: View {
    var body: some View {
        VStack(spacing: 0) {
            Color.clear
            WebRepresentable().frame(height: 120)
        }
    }
}

final class MobileViewCompositionTests: XCTestCase {

    private var window: UIWindow!

    override func setUp() {
        super.setUp()
        NRMAWebViewPresence.installWindowObservers()
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 400, height: 800))
        window.isHidden = false
    }

    override func tearDown() {
        window.rootViewController = nil
        window.isHidden = true
        window = nil
        super.tearDown()
    }

    private func record(composition: NRViewComposition?, custom: [String: Any]? = nil) -> [String: Any] {
        MobileViewRecord(viewName: "CheckoutView",
                         viewClass: "MyApp.CheckoutView",
                         instanceId: "instance-1",
                         framework: .uiKit,
                         composition: composition,
                         custom: custom).attributes()
    }

    // MARK: - Schema

    // Always written by an automatic producer, false included, so `WHERE containsWebView IS false`
    // matches native screens instead of missing every event that left the attribute out.
    func testANativeVisitWritesAllThreeAsBooleans() {
        let attrs = record(composition: NRViewComposition(containsWebView: false,
                                                          isFullScreenWebView: false,
                                                          isTopLevelView: true))

        XCTAssertEqual(attrs["containsWebView"] as? NSNumber, NSNumber(value: false))
        XCTAssertEqual(attrs["isFullScreenWebView"] as? NSNumber, NSNumber(value: false))
        XCTAssertEqual(attrs["isTopLevelView"] as? NSNumber, NSNumber(value: true))
        // Booleans, not 0/1 integers, so they serialize as JSON true/false.
        XCTAssertTrue(CFGetTypeID(attrs["containsWebView"] as CFTypeRef) == CFBooleanGetTypeID())
    }

    func testAFullScreenWebViewImpliesContainsWebView() {
        let attrs = record(composition: NRViewComposition(containsWebView: false,
                                                          isFullScreenWebView: true,
                                                          isTopLevelView: true))

        XCTAssertEqual(attrs["containsWebView"] as? Bool, true)
        XCTAssertEqual(attrs["isFullScreenWebView"] as? Bool, true)
    }

    // A manual view: the agent never saw the screen, so it does not claim to know.
    func testNoCompositionOmitsAllThree() {
        let attrs = record(composition: nil)

        XCTAssertNil(attrs["containsWebView"])
        XCTAssertNil(attrs["isFullScreenWebView"])
        XCTAssertNil(attrs["isTopLevelView"])
    }

    func testCustomAttributesCannotOverrideThem() {
        let attrs = record(composition: NRViewComposition(containsWebView: false,
                                                          isFullScreenWebView: false,
                                                          isTopLevelView: false),
                           custom: ["containsWebView": true, "isTopLevelView": true, "isFullScreenWebView": true])

        XCTAssertEqual(attrs["containsWebView"] as? Bool, false)
        XCTAssertEqual(attrs["isFullScreenWebView"] as? Bool, false)
        XCTAssertEqual(attrs["isTopLevelView"] as? Bool, false)
    }

    func testCustomAttributesDropTheKeysOnAManualView() {
        let attrs = record(composition: nil, custom: ["containsWebView": true])
        XCTAssertNil(attrs["containsWebView"])
    }

    // The Objective-C producer's path onto the record.
    func testTheObjectiveCFieldsCarryTheComposition() {
        let fields = NRMAMobileViewFields()
        fields.viewName = "WebViewController"
        fields.instanceId = "instance-1"
        fields.uiFramework = "UIKit"
        fields.setComposition(containsWebView: true, isFullScreenWebView: true, isTopLevelView: false)

        let attrs = fields.record()?.attributes() ?? [:]
        XCTAssertEqual(attrs["containsWebView"] as? Bool, true)
        XCTAssertEqual(attrs["isFullScreenWebView"] as? Bool, true)
        XCTAssertEqual(attrs["isTopLevelView"] as? Bool, false)
    }

    func testObjectiveCFieldsWithoutACompositionOmitAllThree() {
        let fields = NRMAMobileViewFields()
        fields.viewName = "Route"
        fields.instanceId = "instance-1"
        fields.manual = true

        XCTAssertNil(fields.record()?.attributes()["containsWebView"])
    }

    // MARK: - SwiftUI representables

    private func host<V: View>(_ view: V) -> UIHostingController<V> {
        let host = UIHostingController(rootView: view)
        window.rootViewController = host
        host.view.frame = window.bounds
        host.view.layoutIfNeeded()
        return host
    }

    private func visit(_ controller: UIViewController) -> NRMAWebViewPresence {
        NRMAWebViewPresence.beginVisit(for: controller)
        return NRMAWebViewPresence.endVisit(for: controller)
    }

    func testASwiftUIScreenWrappingAWebViewIsFullScreen() {
        let presence = visit(host(WebScreen()))

        XCTAssertTrue(presence.containsWebView)
        XCTAssertTrue(presence.isFullScreenWebView)
    }

    func testASwiftUIScreenWithAWebBannerContainsAWebView() {
        let presence = visit(host(BannerScreen()))

        XCTAssertTrue(presence.containsWebView)
        XCTAssertFalse(presence.isFullScreenWebView)
    }

    func testASwiftUIScreenWithNoWebViewReportsNeither() {
        let presence = visit(host(NativeScreen()))

        XCTAssertFalse(presence.containsWebView)
        XCTAssertFalse(presence.isFullScreenWebView)
    }

    // MARK: - isTopLevelView with SwiftUI hosts

    // A NavigationStack destination's host sits in a navigation controller's slot.
    func testAHostInANavigationStackIsTopLevel() {
        let destination = UIHostingController(rootView: NativeScreen())
        _ = UINavigationController(rootViewController: destination)

        XCTAssertTrue(NRMA_IsTopLevelController(destination))
    }

    // A UIViewControllerRepresentable's controller inside a host that is not itself reported: the
    // host is skipped over, and the stack it sits in decides.
    func testAUIKitChildOfAnUnreportedHostIsPlacedByTheStackAboveIt() {
        let host = UIHostingController(rootView: NativeScreen())
        _ = UINavigationController(rootViewController: host)
        let child = UIViewController()
        host.addChild(child)
        host.view.addSubview(child.view)
        child.didMove(toParent: host)

        XCTAssertTrue(NRMA_IsTopLevelController(child))
    }

    // A SwiftUI card embedded in a UIKit screen is part of that screen.
    func testAHostEmbeddedInAUIKitScreenIsNotTopLevel() {
        let screen = UIViewController()
        let card = UIHostingController(rootView: NativeScreen())
        screen.addChild(card)
        screen.view.addSubview(card.view)
        card.didMove(toParent: screen)

        XCTAssertFalse(NRMA_IsTopLevelController(card))
    }
}
