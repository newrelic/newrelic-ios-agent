// swift-tools-version:5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "NewRelic",
    platforms: [
        .iOS(.v12), .macOS(.v10_14), .tvOS(.v12), .watchOS(.v10),
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "NewRelic",
            targets: ["NewRelicPackage", "NewRelic"])
    ],
    targets: [
        .target(
            name: "NewRelicPackage",
            dependencies: []),
        .binaryTarget(
            name: "NewRelic",
            url: "https://download.newrelic.com/ios-v5/NewRelic_XCFramework_Agent_7.5.6-dev.35.zip",
            checksum: "2dac45352819b501969d0b6dc20c5430251e13fdd7c1f3ef5408bd5540a86632"),
    ]
)
