//
//  ListingStubServer.swift
//  HomeSearch
//
//  A local HTTP server serving the listing fixture and procedurally generated listing photos.
//
//  Why serve locally instead of reading the bundle directly: the agent instruments URLSession, so
//  fetching over real HTTP produces genuine MobileRequest events. That lets us check that request
//  events are attributed to the screen that issued them — including the awkward case where a
//  response lands after the user has already navigated away. Reading the JSON straight from the
//  bundle would produce no network events at all.
//
//  It stays deterministic and offline: same fixture every run, no external host to go down.
//
//  Port note: the collector stub has to own 8080 (the agent only accepts plain HTTP at exactly
//  "localhost:8080"), so this server takes 8082 to stay out of its way.
//

import Foundation
import UIKit

final class ListingStubServer {

    static let shared = ListingStubServer()
    static let port: UInt16 = 8082
    static var baseURL: String { "http://127.0.0.1:\(port)" }

    private let server = HttpServer()
    private var isRunning = false

    private init() {}

    func start() {
        guard !isRunning else { return }

        guard let fixture = Self.loadFixtureData() else {
            appLog("[HomeSearch] listings.json missing from bundle — the app will show a load error.")
            return
        }

        // GET /api/listings — the whole fixture.
        server.GET["/api/listings"] = { _ in
            .ok(.data(fixture, contentType: "application/json"))
        }

        // GET /api/listings/:id — one listing, so the detail screen issues its own request and we
        // get a MobileRequest event attributed to Listing Detail rather than to Search.
        server.GET["/api/listings/:id"] = { request in
            let id = request.params[":id"] ?? ""
            guard
                let response = try? JSONDecoder().decode(ListingsResponse.self, from: fixture),
                let listing = response.listings.first(where: { $0.id == id }),
                let body = try? JSONEncoder().encode(listing)
            else {
                return .notFound(.json(["error": "no listing \(id)"] as AnyObject))
            }
            return .ok(.data(body, contentType: "application/json"))
        }

        // GET /photo/:id/:index.png — procedurally drawn so imagery needs no binary assets and is
        // identical across runs.
        server.GET["/photo/:id/:index"] = { request in
            let id = request.params[":id"] ?? "L-0000"
            let indexPart = (request.params[":index"] ?? "0").replacingOccurrences(of: ".png", with: "")
            let index = Int(indexPart) ?? 0
            guard let png = Self.photo(listingID: id, index: index) else {
                return .notFound(nil)
            }
            return .ok(.data(png, contentType: "image/png"))
        }

        do {
            try server.start(Self.port, forceIPv4: true)
            isRunning = true
            appLog("[HomeSearch] Listing stub server on \(Self.baseURL)")
        } catch {
            appLog("[HomeSearch] Listing stub server failed to start: \(error)")
        }
    }

    func stop() {
        server.stop()
        isRunning = false
    }

    // MARK: - Fixture

    private static func loadFixtureData() -> Data? {
        guard let url = Bundle.main.url(forResource: "listings", withExtension: "json") else {
            return nil
        }
        return try? Data(contentsOf: url)
    }

    // MARK: - Procedural photos

    /// Draws a stylised property photo: a hue-shifted sky gradient, a horizon, and a simple house
    /// silhouette whose proportions vary by index. Deterministic for a given (listing, index).
    private static func photo(listingID: String, index: Int) -> Data? {
        let hue = Self.hue(for: listingID)
        let size = CGSize(width: 800, height: 600)
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { context in
            let cg = context.cgContext

            // Sky
            let top = UIColor(hue: hue, saturation: 0.30, brightness: 0.95, alpha: 1)
            let bottom = UIColor(hue: hue, saturation: 0.55, brightness: 0.62, alpha: 1)
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                         colors: [top.cgColor, bottom.cgColor] as CFArray,
                                         locations: [0, 1]) {
                cg.drawLinearGradient(gradient,
                                      start: .zero,
                                      end: CGPoint(x: 0, y: size.height),
                                      options: [])
            }

            // Ground
            UIColor(hue: 0.28, saturation: 0.35, brightness: 0.52, alpha: 1).setFill()
            cg.fill(CGRect(x: 0, y: size.height * 0.68, width: size.width, height: size.height * 0.32))

            // House body — width and roof pitch shift with the photo index so a gallery of six
            // reads as six different shots rather than one repeated.
            let variance = CGFloat(index % 5) * 0.04
            let bodyWidth = size.width * (0.34 + variance)
            let bodyHeight = size.height * 0.30
            let bodyX = (size.width - bodyWidth) / 2
            let bodyY = size.height * 0.68 - bodyHeight
            let body = CGRect(x: bodyX, y: bodyY, width: bodyWidth, height: bodyHeight)

            UIColor(white: 0.97, alpha: 1).setFill()
            cg.fill(body)

            let roof = UIBezierPath()
            roof.move(to: CGPoint(x: bodyX - 24, y: bodyY))
            roof.addLine(to: CGPoint(x: bodyX + bodyWidth / 2, y: bodyY - size.height * (0.14 + variance)))
            roof.addLine(to: CGPoint(x: bodyX + bodyWidth + 24, y: bodyY))
            roof.close()
            UIColor(hue: hue, saturation: 0.45, brightness: 0.38, alpha: 1).setFill()
            roof.fill()

            // Windows
            UIColor(hue: 0.58, saturation: 0.40, brightness: 0.80, alpha: 1).setFill()
            let windowSize = bodyWidth * 0.16
            for column in 0..<2 {
                let x = bodyX + bodyWidth * (column == 0 ? 0.18 : 0.62)
                cg.fill(CGRect(x: x, y: bodyY + bodyHeight * 0.22,
                               width: windowSize, height: windowSize))
            }

            // Door
            UIColor(hue: hue, saturation: 0.50, brightness: 0.30, alpha: 1).setFill()
            cg.fill(CGRect(x: bodyX + bodyWidth * 0.42,
                           y: bodyY + bodyHeight * 0.55,
                           width: bodyWidth * 0.16,
                           height: bodyHeight * 0.45))

            // Photo index caption, so it is obvious which frame of the gallery is on screen.
            let caption = "\(listingID) · photo \(index + 1)"
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 26, weight: .semibold),
                .foregroundColor: UIColor(white: 1, alpha: 0.92)
            ]
            caption.draw(at: CGPoint(x: 24, y: size.height - 46), withAttributes: attributes)
        }.pngData()
    }

    /// Stable hue derived from the listing id, so photos match the card colour without the server
    /// needing to decode the fixture on every image request.
    private static func hue(for listingID: String) -> CGFloat {
        let digits = listingID.compactMap(\.wholeNumberValue).reduce(0, +)
        return CGFloat(digits % 20) / 20.0
    }
}
