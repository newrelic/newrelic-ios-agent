# NRTestApp

## Overview
NRTestApp is an example app used to test the functionality of the New Relic iOS agent. Inside the NRTestApp.xcodeproj project there are example apps for iOS, tvOS and watchOS. The example apps are useful for demonstrating how to configure and start the iOS agent in your project. It can also be used to send test data to [NR One](https://newrelic.com/welcome-back) and see how data is shown on our website.


## Setup
- Add your New Relic application token to `NRAPIInfo.plist` as a String under the key `NRAPIKey`.
- To test symbolication of crashes and handled exceptions add your New Relic application token to the `Run New Relic dSYM upload run-symbol-tool` build phase under the Target of the test app you want to run.
- In AppDelegate.swift or WatchAppDelegate.swift adjust the [feature flags](https://docs.newrelic.com/docs/mobile-monitoring/new-relic-mobile/mobile-sdk/configure-settings/#ios) for the functionality you would like to test.
- Check the [docs website](https://docs.newrelic.com/docs/mobile-monitoring/new-relic-mobile-ios/get-started/introduction-new-relic-mobile-ios/) for more information on how to configure the iOS agent.
