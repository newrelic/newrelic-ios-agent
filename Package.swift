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
            url: "https://download.newrelic.com/ios-v5/NewRelic_XCFramework_Agent_7.5.7-dev.42.zip",
            checksum: "215c3d15b21f520049a6a751283e971bb5b1a11f7030d719ee0d9e283f999e4c"),

    ]
)
