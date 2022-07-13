# 🍏 dylib-ios-agent 🍎
Xcode workspace containing New Relic iOS Agent source code. Agent is packaged as a XCFramework.  Framework is available as a zip download, via cocoapods, and via Swift Package Manager.

Agent supports tvOS 📺, macOS 💻, and iOS 📱.
***

## 🏡 Tour of this Repository
```
dylib-ios-agent
├─ Agent.xcworkspace     // Open this for Dev and Testing
├─ Agent.xcodeproj
├─ Agent/                // Contains library target source
│  ├─ General
│     └─ NewRelicAgentInternal.h/.m // Public API Impl
│  ├─ Public
│     └─ NewRelic.h/.m   // Public API
│  ├─ ...                // Agent Source code
├─ libMobileAgent/       // GITSUBMOULE: 4 Internal C++ libs
│  ├─ src
│    ├─ Analytics
│    ├─ Connectivity
│    ├─ Hex
│    ├─ Utilities
│  ├─ build               // Generated output of libMobileAgent build
├─ Frameworks/            // Generated output of libMobileAgent build
├─ modular-crash-reporter-ios/ // GITSUBMOULE: PLCrashReporter
├─ Tests/                 // Agent Test files
├─ dsym-upload-tools/     // DSYM upload script newrelic_postbuild
├─ scripts/               // Deployment Shell scripts
├─ cocoapods/             // Cocoapods files
├─ NewRelic-SwiftPackage/ // SPM files
```
## 🎬 Getting Started
To check out the code run the following git command. Note the recursive submodule addition to make sure we get the repos git submodules.

`git clone git@source.datanerd.us:mobile/dylib-ios-agent.git --recurse-submodules`

The libMobileAgent Xcode build script requires cmake in order to run. Install it via brew.

`brew install cmake`

Open `dylib-ios-agent/Agent.xcworkspace` using the Finder.

Build `Agent-iOS` by pressing the play button.

## 📚 Docs
- [Public Docs on docs.newrelic.com](https://docs.newrelic.com/docs/mobile-monitoring/new-relic-mobile-ios/get-started/introduction-new-relic-mobile-ios)

## 📱 Example Usage
See GHE repo [TestAppAPOD](https://source.datanerd.us/mobile/TestAppAPOD). This repo brings in NewRelic.xcframework and is a project that is easily used to test the Agent source code. To do this just drag the `APODBrowser.xcodeproject` into the Agent workspace (above the Agent project.) 

## 🚀 Deployment CI/CD
Deployment multijob can be seen in Jenkins here:
[MultiJob Project iOS-Dylib-CI](https://mobile-team-build.pdx.vm.datanerd.us/view/Agent%20-%20iOS%20Dylib/job/iOS-Dylib-CI/) 

[All dylib-ios-agent Jenkins jobs](https://mobile-team-build.pdx.vm.datanerd.us/view/Agent%20-%20iOS%20Dylib/)

## Cocoapods
[Jenkins Cocoapods Staging Job](https://mobile-team-build.pdx.vm.datanerd.us/job/Agent-XCFramework-Staging-Cocoapods/)

[Jenkins Cocoapods Prod Job](https://mobile-team-build.pdx.vm.datanerd.us/job/Agent-Production-Release_XCFramework-Cocoapods/)

## 📦 SPM
[Jenkins SPM Staging Job](https://mobile-team-build.pdx.vm.datanerd.us/view/Agent%20-%20iOS%20Dylib/job/Agent-XCFramework-Staging-SwiftPM/)

[Jenkins SPM Job Prod](https://mobile-team-build.pdx.vm.datanerd.us/view/Agent%20-%20iOS%20Dylib/job/Agent-Production-Release_XCFramework-SPM/)

## 🎤 Testing
- Option 1: Run the Unit Tests using Xcode by selecting Agent-iOS scheme and Product -> Test
- View Code Coverage report by running `./XcodeCoverage/getcov -s -v`
    - Note: If you are on a pre M1 architecture then please uncomment the x86 line and remove the arm64 line in the file `XcodeCoverage/envcov.sh`
    ```
    # PRE M1
    #ARCHITECTURE="x86_64"

    # M1
    ARCHITECTURE="arm64"
    ```
    - Note: Run `./XcodeCoverage/covlcean` in between test runs to make sure latest code coverage data is used.
- Option 2: Running tests using [Fastlane](https://docs.fastlane.tools/)
    - Prerequisites:
        - Requires ruby (ruby 2.6.8p205 was used) 
        - Requires Bundler (use gem install bundler) (Bundler 2.3.13 was used)
        - Requires running bundle install before fastlane
    - `bundle exec fastlane runIOSTests`
        - Run above command to delete build artifacts and run tests on iOS. Upon completion code coverage will be generated.
    - `bundle exec fastlane runTests`
        - To run the Agent iOS Tests and tvOS Tests run the above command.
- Building NewRelic.XCFramework using Fastlane
    - `bundle exec fastlane testAndBuild`
        - To run tests and then build the framework run above command.
    - `bundle exec fastlane buildFramework`
        - To build the framework run above command.
- Utilities:
    - `bundle exec fastlane deleteBuildArtifacts` Run this command to nuke the projects build caches.

## ⁉️ Troubleshooting
- If you encounter a build error then try deleting the `libMobileAgent/build` and `Frameworks` folders and trying another build.
- Xcode must have default name of `Xcode.app`

## 🦅 History
Development on the New Relic iOS Agent began in late May 2012. Development continued in the [ios_agent](https://source.datanerd.us/mobile/ios_agent) repository until August 2020. At this point the source was moved into this repository dylib-ios-agent.

## 🔗 Links
- [libMobileAgent](https://source.datanerd.us/mobile/libMobileAgent) C++ Project containing 4 libraries.
- [modular-crash-reporter-ios (aka PLCrashReporter)](https://github.com/microsoft/plcrashreporter) Crash reporting brought in as a submodule using this library.
- [Old ios_agent Repo](https://source.datanerd.us/mobile/ios_agent) GHE Repo used until 2020.
- [README DSYM UPLOAD TOOLS ](README-DSYM-UPLOAD-TOOLS.md) README pertaining to dependencies of newrelic_postbuild.sh script.
- [NewRelicAgent-SPM GHE](https://source.datanerd.us/mobile/NewRelicAgent-SPM) The repo dev builds publish swift package to.
- [NewRelic SPM Prod](https://github.com/newrelic/newrelic-ios-agent-spm) The repo release builds publish swift packages to.