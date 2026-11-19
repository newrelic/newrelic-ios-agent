import Foundation
import Testing
import UIKit

@MainActor
struct SessionReplayClippingTests {
    // A product page: a vertical scroll view under a 100pt header, holding a horizontal
    // image carousel. Scrolling the page pushes the carousel up under the header.
    func makeScrolledCarousel() -> (window: UIWindow, image: UIView) {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 400, height: 800))
        let page = UIScrollView(frame: CGRect(x: 0, y: 100, width: 400, height: 700))
        page.contentSize = CGSize(width: 400, height: 2000)
        page.contentOffset = CGPoint(x: 0, y: 250)
        let carousel = UIScrollView(frame: CGRect(x: 0, y: 0, width: 400, height: 300))
        carousel.contentSize = CGSize(width: 1200, height: 300)
        let image = UIView(frame: CGRect(x: 0, y: 0, width: 400, height: 300))

        window.addSubview(page)
        page.addSubview(carousel)
        carousel.addSubview(image)
        return (window, image)
    }

    @Test func `View in nested scroll views is clipped by the outer one too`() {
        let (window, image) = makeScrolledCarousel()

        let details = ViewDetails(view: image)

        // Only the 50pt of the image still inside the page's viewport (y 100...150) is
        // visible; the rest is under the header.
        #expect(details.clip == CGRect(x: 0, y: 100, width: 400, height: 50))
        #expect(details.frame == CGRect(x: 0, y: 100, width: 400, height: 50))
        _ = window
    }

    @Test func `View scrolled out of the outer scroll view is not visible`() {
        let (window, image) = makeScrolledCarousel()
        (image.superview?.superview as? UIScrollView)?.contentOffset = CGPoint(x: 0, y: 600)

        #expect(!ViewDetails(view: image).isVisible)
        _ = window
    }
}
