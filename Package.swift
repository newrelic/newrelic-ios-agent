// swift-tools-version:5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "NewRelic",
    platforms: [
        .iOS(.v12), .macOS(.v10_14), .tvOS(.v12), .watchOS(.v10)
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
                      url: "https://download.newrelic.com/ios-v5/NewRelic_XCFramework_Agent_7.5.10-rc.1645.zip",
                      checksum: "2a958fd4f5ffa4ee3f29920a19fc8f8818d522a9cd64bfbf595a4bd7db074309")
    ]
)

