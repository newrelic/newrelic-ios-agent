// swift-tools-version:5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "NewRelicAgent",
    platforms: [
        .iOS(.v12), .macOS(.v10_14), .tvOS(.v12), .watchOS(.v10),
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "NewRelicAgent",
            targets: ["NewRelicPackage", "NewRelicAgent"])
    ],
    targets: [
        .target(
            name: "NewRelicPackage",
            dependencies: []),
        .binaryTarget(
            name: "NewRelicAgent",
            url: "https://download.newrelic.com/ios-v5/NewRelic_XCFramework_Agent_7.5.6-dev.27.zip",
            checksum: "a172e49c03abba1556acc4282811030f11a5a0029847aa873f61049cce164805"),
    ]
)
