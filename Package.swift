// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "NewRelic",
    platforms: [
        .iOS(.v9), .macOS(.v10_14)
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
                      url: "https://download.newrelic.com/ios-v5/NewRelic_XCFramework_Agent_7.4.4-rc.318.zip",
                      checksum: "f0b1544c5e43cbc7168047c369b8c3a442c15625feb0d693d7526b08306a5a61")
    ]
)

