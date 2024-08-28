<a href="https://opensource.newrelic.com/oss-category/#community-plus"><picture><source media="(prefers-color-scheme: dark)" srcset="https://github.com/newrelic/opensource-website/raw/main/src/images/categories/dark/Community_Plus.png"><source media="(prefers-color-scheme: light)" srcset="https://github.com/newrelic/opensource-website/raw/main/src/images/categories/Community_Plus.png"><img alt="New Relic Open Source community plus project banner." src="https://github.com/newrelic/opensource-website/raw/main/src/images/categories/Community_Plus.png"></picture></a>

# New Relic iOS Agent
New Relic's mobile monitoring capabilities help you gain deeper visibility into how to analyze your iOS application performance and troubleshoot crashes. You can also examine HTTP and other network performance for unexpected lag, which will in turn help you collaborate more efficiently with your backend teams.

**New Relic iOS Agent supports iOS 📱, tvOS 📺, watchOS ⌚️, and macOS (Catalyst) 💻.**

This repository consists of an Xcode workspace containing the New Relic iOS Agent source code. The Agent is packaged as an XCFramework.  The framework is available via **Swift Package Manager (preferred installation method)**, Cocoapods, and as a zip file download.

See the [XCFramework agent release notes](https://docs.newrelic.com/docs/release-notes/mobile-release-notes/xcframework-release-notes/) for the latest release information. These release notes contain the link to the XCFramework zip file download.

## Documentation
- [Public Documentation on docs.newrelic.com](https://docs.newrelic.com/docs/mobile-monitoring/new-relic-mobile-ios/get-started/introduction-new-relic-mobile-ios)

## Installation
1. From Xcode select **File > Swift Packages > Add Package Dependency...**.
2. Add the Github URL of the Package file:
  
  ```
  https://github.com/newrelic/newrelic-ios-agent
  ```
See Swift Package Manager agent installation [instructions](https://docs.newrelic.com/docs/mobile-monitoring/new-relic-mobile-ios/installation/spm-installation/) for more info.

View the docs for more installation methods.

## Getting Started
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
An example app which demonstrates usage of the New Relic iOS Agent is included in the Agent workspace. 

- From Xcode change to the NRTestApp scheme to run the example app.
- Add your New Relic application token to `NRAPIInfo.plist` as a String under the key `NRAPIKey`.
- For more information see the [README.md](https://github.com/newrelic/newrelic-ios-agent/blob/main/Test%20Harness/NRTestApp/README.md) in the NRTestApp directory.

## dSYM Upload Tools

By default, the New Relic iOS Agent will report crashes to New Relic. In order to view symbolicated crashes, your app must upload its debugging symbols to New Relic. The Agent contains the run-symbol-tool script for this purpose.

- Xcode Run Script: Copy and paste the following line, replacing `APP_TOKEN` with your [application token](https://docs.newrelic.com/docs/mobile-monitoring/new-relic-mobile/maintenance/viewing-your-application-token):

#### iOS agent 7.4.0 or higher:
```
ARTIFACT_DIR="${BUILD_DIR%Build/*}"
SCRIPT=`/usr/bin/find "${SRCROOT}" "${ARTIFACT_DIR}" -type f -name run-symbol-tool | head -n 1`
/bin/sh "${SCRIPT}" "APP_TOKEN"
```

- Add `--debug` as additional argument after the app token to write additional details to the `upload_dsym_results.log` file.

#### iOS agent 7.3.8 or lower:
```
SCRIPT=`/usr/bin/find "${SRCROOT}" -name newrelic_postbuild.sh | head -n 1`

if [ -z "${SCRIPT}"]; then
    ARTIFACT_DIR="${BUILD_DIR%Build/*}SourcePackages/artifacts"
    SCRIPT=`/usr/bin/find "${ARTIFACT_DIR}" -name newrelic_postbuild.sh | head -n 1`
fi

/bin/sh "${SCRIPT}" "APP_TOKEN"
```

#### OPTIONAL:
Add the following lines to your build script above the existing lines to skip symbol upload during debugging:
```
if [ ${CONFIGURATION} = "Debug" ]; then
    echo "Skipping DSYM upload CONFIGURATION: ${CONFIGURATION}"
    exit 0
fi
```

#### Note for Cocoapods or manual XCFramework integration:
With the 7.4.6 release the dsym-upload-tools are no longer included inside the XCFramework. The dsym-upload-tools are available in the dsym-upload-tools folder of the https://github.com/newrelic/newrelic-ios-agent-spm Swift Package Manager repository. Please copy this dsym-upload-tools directory to your applications source code directory if you are integrating the New Relic iOS Agent by copying XCFramework into project or using cocoapods.

The run-symbol-tool Run script must be added to your app's Xcode project build phases.

- `dsym-upload-tools/run-symbol-tool`: Shell script which is used to bootstrap Swift script.
- `dsym-upload-tools/run-symbol-tool.swift`: Swift script which converts dSYMs to map files and uploads to New Relic.

## Building
- To check out the code, run the following git command. Note the recursive submodule addition to make sure we get the repo's git submodules.
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
        - Run above command to run tests on iOS. Upon completion, code coverage will be generated. 
            - run `brew install lcov` to add lcov for code coverage.

## Links
- [newrelic-ios-agent-spm](https://github.com/newrelic/newrelic-ios-agent-spm) Released Swift packages are published here. 
- [modular-crash-reporter-ios (aka PLCrashReporter)](https://github.com/microsoft/plcrashreporter) Crash reporting brought in as a submodule using this library.

## Support

New Relic hosts and moderates an online forum where customers can interact with New Relic employees as well as other customers to get help and share best practices. Like all official New Relic open source projects, there's a related Community topic in the New Relic Explorers Hub. You can find this project's topic/threads here:
[Mobile topic on forum.newrelic.com](https://forum.newrelic.com/s/?c__categories=%5B%7B%22id%22%3A%22a6c8W000000EesdQAC%22%2C%22isCustomImage%22%3Afalse%2C%22sObjectType%22%3A%22Category__c%22%2C%22subtitle%22%3A%22%22%2C%22title%22%3A%22Mobile%22%2C%22titleFormatted%22%3A%22%3Cstrong%3EMob%3C%2Fstrong%3Eile%22%2C%22subtitleFormatted%22%3A%22%22%2C%22icon%22%3A%22standard%3Adefault%22%7D%5D)

## Contribute

We encourage your contributions to improve New Relic iOS Agent! Keep in mind that, when you submit your pull request, you'll need to sign the CLA via the click-through using CLA-Assistant. You only have to sign the CLA one time per project.

If you have any questions, or to execute our corporate CLA (which is required if your contribution is on behalf of a company), drop us an email at opensource@newrelic.com.

**A note about vulnerabilities**

As noted in our [security policy](../../security/policy), New Relic is committed to the privacy and security of our customers and their data. We believe that providing coordinated disclosure by security researchers and engaging with the security community are important means to achieve our security goals.

If you believe you have found a security vulnerability in this project or any of New Relic's products or websites, we welcome and greatly appreciate you reporting it to New Relic through [HackerOne](https://hackerone.com/newrelic).

If you would like to contribute to this project, review [these guidelines](./CONTRIBUTING.md).

To all contributors, we thank you!  Without your contribution, this project would not be what it is today.  We also host a community project page dedicated to [New Relic iOS agent](https://opensource.newrelic.com/).

## License
New Relic iOS Agent is licensed under the [Apache 2.0](http://apache.org/licenses/LICENSE-2.0.txt) License.
The New Relic iOS agent also uses source code from third-party libraries. Full details on which libraries are used and the terms under which they are licensed can be found  in the [third-party notices](./THIRD_PARTY_NOTICES.md).
