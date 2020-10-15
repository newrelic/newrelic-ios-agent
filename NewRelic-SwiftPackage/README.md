# NewRelic-SwiftPackage

todo: 
 - add notes on how to release the swift package

Generating a new checksum : 
When a new version of the xcframework is released use `swift package compute-checksum path/to/MyFramework.zip`  to generate a new checksum. This command must be run in the same folder as the package.swift.
