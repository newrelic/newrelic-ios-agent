// swift-tools-version:5.7
//
// Development package for run-symbol-tool, used to run its unit tests (`swift test`).
// Customers never build this package: the run-symbol-tool wrapper compiles Sources/SymbolTool directly with swiftc.

import PackageDescription

let package = Package(
    name: "dsym-upload-tools",
    platforms: [.macOS(.v10_15)],
    targets: [
        .executableTarget(name: "SymbolTool", path: "Sources/SymbolTool"),
        .testTarget(name: "SymbolToolTests",
                    dependencies: ["SymbolTool"],
                    path: "Tests/SymbolToolTests",
                    resources: [.copy("Fixtures")]),
    ]
)
