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
            targets: ["NewRelic"]),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .binaryTarget(name: "NewRelic",
                      url: "https://download.newrelic.com/ios-v5/NewRelic_XCFramework_Agent_7.4.1-dev.51.zip",
                      checksum: "00bf2db680d3f8be07c4c1b7cfe0fa871532de5a3b81853d11a2f0bef0e479b9")
    ]
)

