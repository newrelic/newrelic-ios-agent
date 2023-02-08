[![Community Plus header](https://github.com/newrelic/opensource-website/raw/main/src/images/categories/Community_Plus.png)](https://opensource.newrelic.com/oss-category/#community-plus)

# New Relic iOS Agent
New Relic's mobile monitoring capabilities help you gain deeper visibility into how to analyze your iOS application performance and troubleshoot crashes. You can also examine HTTP and other network performance for unexpected lag, which will in turn help you collaborate more efficiently with your backend teams.

**New Relic iOS Agent supports iOS 📱, tvOS 📺, and macOS (Catalyst) 💻.**

This repository consists of an Xcode workspace containing New Relic iOS Agent source code. Agent is packaged as a XCFramework.  Framework is available via **Swift Package Manager (preferred installation method)**, Cocoapods, and as a zip  file download.

See the [XCFramework agent release notes](https://docs.newrelic.com/docs/release-notes/mobile-release-notes/xcframework-release-notes/) for latest release information.

## 📚 Docs
- [Public Docs on docs.newrelic.com](https://docs.newrelic.com/docs/mobile-monitoring/new-relic-mobile-ios/get-started/introduction-new-relic-mobile-ios)

## Installation

1. From Xcode Select **File > Swift Packages > Add Package Dependency...**.
2. Add the Github URL of the Package file:
  
  ```
  https://github.com/newrelic/newrelic-ios-agent-spm
  ```
See Docs for more installation methods.

## Getting Started

[🚧UNDER CONSTRUCTION🚧]

If you have not created a Mobile Application in New Relic:

* Click "+ Add data" in the top right,
* In the Browser & Mobile section - please select the iOS tile, Select your Account
* Name your app
* Install the New Relic iOS Agent to your supported application. This should be an iOS, tvOS, or Catalyst app. Follow the instructions to install via the Swift Package Manager
* You can also select the "+ Add data" option from the user menu in the upper right corner of the top navigation, then the iOS button to access the installation page.

If you have previously created a Mobile Application in New Relic:

* Click the name of your mobile app,
* Choose Installation from the Settings section in the left nav, and
* Install the New Relic iOS Agent to your supported application. This should be an iOS, tvOS, or Catalyst app. Follow the instructions to install via the Swift Package Manager

## Usage

[🚧UNDER CONSTRUCTION🚧]

>[**Optional** - Include more thorough instructions on how to use the software. This section might not be needed if the Getting Started section is enough. Remove this section if it's not needed.]

An example app which demonstrates usage of the New Relic iOS Agent is included in the Agent workspace.

By default the New Relic iOS Agent will report crashes to New Relic. In order to view the crashes symbolicated your app must upload its debugging symbols to New Relic. The Agent contains the run-symbol-tool script for this purpose.

The run-symbol-tool Run script must be added to your apps Xcode projects build phases.
## ⬆️ dSYM Upload Tools
- `dsym-upload-tools/run-symbol-tool`: Shell script which is used to bootstrap Swift script.
- `dsym-upload-tools/run-symbol-tool.swift`: Swift script which converts dSYMs to map files and uploads to New Relic.

    - Xcode Run Script: Copy and Paste the following line, replacing `APP_TOKEN` with your [application token](https://docs.newrelic.com/docs/mobile-monitoring/new-relic-mobile/maintenance/viewing-your-application-token):
    ```
    "${BUILD_DIR%/Build/*}/SourcePackages/artifacts/newrelic-ios-agent-spm/NewRelic.xcframework/Resources/run-symbol-tool" "APP_TOKEN"
    ```
    - Remove `-spm` from path if using this `newrelic-ios-agent` repo for SPM url.
    - Add `--debug` as additional argument after the app token to write additional details to the `upload_dsym_results.log` file.

## Building
- To check out the code run the following git command. Note the recursive submodule addition to make sure we get the repos git submodules.
    - `git clone git@github.com:newrelic/newrelic-ios-agent.git --recurse-submodules`

- Open `newrelic-ios-agent/Agent.xcworkspace` using the Finder.
- Option 1: Build using Xcode.
- Option 2: Build using [Fastlane](https://docs.fastlane.tools/)
    - `bundle exec fastlane buildFramework`
        - Run the above command to create the New Relic iOS Agent XCFramework.

## Testing
- Option 1: Run the Unit Tests using Xcode by selecting Agent-iOS scheme and Product -> Test
- Option 2: Running tests using [Fastlane](https://docs.fastlane.tools/)
    - `bundle exec fastlane runIOSTests`
        - Run above command to run tests on iOS. Upon completion code coverage will be generated.

## 🔗 Links
- [newrelic-ios-agent-spm](https://github.com/newrelic/newrelic-ios-agent-spm) The repo release builds publish swift packages to.
- [modular-crash-reporter-ios (aka PLCrashReporter)](https://github.com/microsoft/plcrashreporter) Crash reporting brought in as a submodule using this library.

## Support

New Relic hosts and moderates an online forum where customers can interact with New Relic employees as well as other customers to get help and share best practices. Like all official New Relic open source projects, there's a related Community topic in the New Relic Explorers Hub. You can find this project's topic/threads here:

[🚧UNDER CONSTRUCTION🚧]
>Add the url for the support thread here: discuss.newrelic.com

## Contribute

We encourage your contributions to improve New Relic iOS Agent Keep in mind that when you submit your pull request, you'll need to sign the CLA via the click-through using CLA-Assistant. You only have to sign the CLA one time per project.

If you have any questions, or to execute our corporate CLA (which is required if your contribution is on behalf of a company), drop us an email at opensource@newrelic.com.

**A note about vulnerabilities**

As noted in our [security policy](../../security/policy), New Relic is committed to the privacy and security of our customers and their data. We believe that providing coordinated disclosure by security researchers and engaging with the security community are important means to achieve our security goals.

If you believe you have found a security vulnerability in this project or any of New Relic's products or websites, we welcome and greatly appreciate you reporting it to New Relic through [HackerOne](https://hackerone.com/newrelic).

If you would like to contribute to this project, review [these guidelines](./CONTRIBUTING.md).

[🚧UNDER CONSTRUCTION🚧]
To all contributors, we thank you!  Without your contribution, this project would not be what it is today.  We also host a community project page dedicated to [Project Name](<LINK TO https://opensource.newrelic.com/projects/... PAGE>).

## License
New Relic iOS Agent is licensed under the [Apache 2.0](http://apache.org/licenses/LICENSE-2.0.txt) License.
The New Relic iOS agent also uses source code from third-party libraries. Full details on which libraries are used and the terms under which they are licensed can be found  in the [third-party notices](./THIRD_PARTY_NOTICES.md).
