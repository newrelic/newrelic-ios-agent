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

Run Agent tests for iOS and generate code coverage

### ios internalRunIOSTests

```sh
[bundle exec] fastlane ios internalRunIOSTests
```



### ios runIOSTestsNoCov

```sh
[bundle exec] fastlane ios runIOSTestsNoCov
```

Run Agent tests for iOS

### ios runIOSBetaTests

```sh
[bundle exec] fastlane ios runIOSBetaTests
```

Run Agent tests for iOS beta

### ios runIOSAppBetaTests

```sh
[bundle exec] fastlane ios runIOSAppBetaTests
```

Run App tests for iOS beta

### ios runTVOSTests

```sh
[bundle exec] fastlane ios runTVOSTests
```

Run Agent tests for tvOS

### ios runTVOSBetaTests

```sh
[bundle exec] fastlane ios runTVOSBetaTests
```

Run Agent tests for tvOS beta

### ios runTVOSAppBetaTests

```sh
[bundle exec] fastlane ios runTVOSAppBetaTests
```

Run Agent tests for tvOS beta

### ios runWatchOSTests

```sh
[bundle exec] fastlane ios runWatchOSTests
```

Run Agent tests for watchOS

### ios runWatchOSBetaTests

```sh
[bundle exec] fastlane ios runWatchOSBetaTests
```

Run Agent tests for watchOS beta

### ios runWatchOSAppBetaTests

```sh
[bundle exec] fastlane ios runWatchOSAppBetaTests
```

Run Agent tests for watchOS beta

### ios coverage

```sh
[bundle exec] fastlane ios coverage
```



### ios runDsymUploadToolsTests

```sh
[bundle exec] fastlane ios runDsymUploadToolsTests
```

Run dSYM Upload Tools test

### ios clean

```sh
[bundle exec] fastlane ios clean
```



### ios deleteBuildArtifacts

```sh
[bundle exec] fastlane ios deleteBuildArtifacts
```

Delete derived data and Frameworks and build directory

### ios addAPIKeyToPlist

```sh
[bundle exec] fastlane ios addAPIKeyToPlist
```

Add an API key to the plist file

### ios internalOutputXCFramework

```sh
[bundle exec] fastlane ios internalOutputXCFramework
```

Ouput Universal NewRelic.xcframework

### ios cpDsymToolsToFramework

```sh
[bundle exec] fastlane ios cpDsymToolsToFramework
```

Copy dsym-upload-tools to xcframework

### ios codesignFramework

```sh
[bundle exec] fastlane ios codesignFramework
```

Codesign xcframework

### ios internalOutputXCFrameworkIOSOnly

```sh
[bundle exec] fastlane ios internalOutputXCFrameworkIOSOnly
```

Ouput Universal NewRelic.xcframework for iOS Only

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

### ios buildWatchOS

```sh
[bundle exec] fastlane ios buildWatchOS
```

Build watchOS.xcarchive / watchOS Sim framework

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

### ios buildAndZip

```sh
[bundle exec] fastlane ios buildAndZip
```



### ios zipFramework

```sh
[bundle exec] fastlane ios zipFramework
```



### ios buildFrameworkIOSOnly

```sh
[bundle exec] fastlane ios buildFrameworkIOSOnly
```

Build NewRelic.XCFramework for iOS Only

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
