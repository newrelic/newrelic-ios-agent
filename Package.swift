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
            url: "https://download.newrelic.com/ios-v5/NewRelic_XCFramework_Agent_7.5.6-dev.28.zip",
            checksum: "ba6603060e7c5cb31fce5c9d3ad088b22cb0703de5315cc11f60436b420b8017"),
    ]
)
