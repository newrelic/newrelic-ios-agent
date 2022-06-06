fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## iOS

### ios runTests

```sh
[bundle exec] fastlane ios runTests
```

Run Agent tests for iOS and tvOS

### ios runIOSTests

```sh
[bundle exec] fastlane ios runIOSTests
```



### ios runTVOSTests

```sh
[bundle exec] fastlane ios runTVOSTests
```



### ios deleteBuildArtifacts

```sh
[bundle exec] fastlane ios deleteBuildArtifacts
```

Delete derived data and Frameworks and build directory

### ios internalOutputXCFramework

```sh
[bundle exec] fastlane ios internalOutputXCFramework
```

Ouput Universal NewRelic.xcframework

### ios buildIOS

```sh
[bundle exec] fastlane ios buildIOS
```

Build iOS.xcarchive / iOS Sim framework

### ios buildTVOS

```sh
[bundle exec] fastlane ios buildTVOS
```

Build tvOS.xcarchive / tvOS Sim framework

### ios buildMacOS

```sh
[bundle exec] fastlane ios buildMacOS
```

Build macOS.xcarchive

### ios generateVersion

```sh
[bundle exec] fastlane ios generateVersion
```

Set build string based on branch and build number

### ios buildFramework

```sh
[bundle exec] fastlane ios buildFramework
```

Build NewRelic.XCFramework for all platforms

### ios testAndBuild

```sh
[bundle exec] fastlane ios testAndBuild
```

Run Tests for iOS/tvOS and Build NewRelic.XCFramework for all platforms

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
