// swift-tools-version:5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "NewRelic",
    platforms: [
        .iOS(.v15), .macOS(.v10_14), .tvOS(.v15), .watchOS(.v10)
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "NewRelic",
            targets: ["NewRelicPackage", "NewRelic"]),
    ],
    targets: [
        .target(
            name: "NewRelicPackage",
            dependencies: []),
        .binaryTarget(name: "NewRelic",
                      url: "https://download.newrelic.com/ios-v5/NewRelic_XCFramework_Agent_7.7.3-rc.2473.zip",
                      checksum: "a5acff1595eeec3d8fb59d7fa7c62fcab90cce9215d3c09fbe90a861839d822c")
    ]
)

