// swift-tools-version:5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "NewRelic",
    platforms: [
        .iOS(.v9), .macOS(.v10_14), .tvOS(.v9), .watchOS(.v10)
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
                      url: "https://download.newrelic.com/ios_agent/NewRelic_XCFramework_Agent_7.5.4.zip",
                      checksum: "e2fc9c71d01c479cb2ed3bd0063e99dc6db22548f98eef7acd663e15346c1f2f")
    ]
)

