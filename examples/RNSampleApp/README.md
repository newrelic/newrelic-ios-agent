# RNSampleApp - React Native Test Application for New Relic iOS Agent

A comprehensive React Native test application for testing the New Relic iOS Agent features, including Session Replay, interaction tracking, and all agent APIs.

## Overview

This sample app is integrated into the `Agent.xcworkspace` and links directly to the local iOS Agent for development and testing. It provides:

- **Custom Tab Navigation**: Home, Lists, Forms, and Utilities screens
- **Session Replay Testing**: Multiple UI interactions, scrolling, form inputs, and navigation
- **Comprehensive Test Utilities**: All New Relic API methods from NRTestApp
- **Native Bridge**: Full access to NewRelic iOS SDK from JavaScript

## Prerequisites

Before setting up the app, ensure you have:

- **Xcode 15+** with iOS SDK
- **Node.js 18+** and npm
- **Ruby 2.7+** (for CocoaPods)
- **CocoaPods** installed (`gem install cocoapods`)
- **New Relic API Key** for testing

## Setup Instructions

### 1. Install JavaScript Dependencies

From the `examples/RNSampleApp` directory:

```bash
cd examples/RNSampleApp
npm install
```

### 2. Install iOS Dependencies

```bash
cd ios
pod install
cd ..
```

### 3. Fill NRAPI-Info.plist inside RNSampleApp Folder

**Required**:
- `NRAPIKey`: Your New Relic application token

**Optional** (leave as empty strings if using default New Relic endpoints):
- `collectorAddress`: Custom collector endpoint (e.g., "staging-mobile-collector.newrelic.com")
- `crashCollectorAddress`: Custom crash collector endpoint (e.g., "staging-mobile-crash.newrelic.com")

### 4. Open the Workspace

**IMPORTANT**: Open `Agent.xcworkspace` at the repository root, NOT `RNSampleApp.xcworkspace`.

```bash
cd ../../../  # Navigate to repository root
open Agent.xcworkspace
```

### 5. Select the Correct Scheme

In Xcode:
1. Click the scheme selector at the top (next to the play/stop buttons)
2. Select **RNSampleApp**
3. Select your target device or simulator

### 6. Build and Run

1. Click the Play button (⌘R) in Xcode to build and run the app
2. The Metro bundler will start automatically
3. The app will launch on your selected device/simulator

If Metro doesn't start automatically:

```bash
cd examples/RNSampleApp
npm start
```


## Platform Configuration

The app is configured in `AppDelegate.mm` to match NRTestApp's setup:

```objc
// Set platform as React Native
[NewRelic setPlatform:NRMAPlatform_ReactNative];

// Enable features
[NewRelic enableFeatures:NRFeatureFlag_NewEventSystem];
[NewRelic enableFeatures:NRFeatureFlag_OfflineStorage];

// Configure event handling
[NewRelic setMaxEventPoolSize:5000];
[NewRelic setMaxEventBufferTime:60];

// Add HTTP header tracking
[NewRelic addHTTPHeaderTrackingFor:@[@"X-Custom-Header"]];
```

## Native Bridge (NRTestBridge)

The `NRTestBridge` module exposes all NewRelic iOS SDK methods to JavaScript:

```javascript
import {NativeModules} from 'react-native';
const {NRTestBridge} = NativeModules;

// Example: Record custom event
NRTestBridge.recordCustomEvent('TestEvent', 'ButtonPressed', {
  testAttribute: 'value',
  timestamp: Date.now(),
});

// Example: Record breadcrumb
NRTestBridge.recordBreadcrumb('UserAction', {
  action: 'View',
  screen: 'DetailScreen',
});
```

See `src/screens/UtilitiesScreen.tsx` for comprehensive usage examples.

## Troubleshooting

### Metro Bundler Issues

If you see "Unable to connect to Metro":

```bash
cd examples/RNSampleApp
npm start -- --reset-cache
```

Then rebuild in Xcode.

### CocoaPods Issues

If pods fail to install:

```bash
cd ios
pod deintegrate
pod install
```

### Xcode Workspace Issues

Make sure you're opening `Agent.xcworkspace` at the repository root, not the nested `RNSampleApp.xcworkspace` in the `ios` folder.
