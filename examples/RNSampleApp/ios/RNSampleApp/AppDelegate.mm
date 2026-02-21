#import "AppDelegate.h"

#import <React/RCTBundleURLProvider.h>
#import <NewRelic/NewRelic.h>

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
  // Initialize New Relic BEFORE React Native
#if DEBUG
  [NRLogger setLogLevels:NRLogLevelDebug];
#endif

  // Read from NRAPI-Info.plist
  NSString *plistPath = [[NSBundle mainBundle] pathForResource:@"NRAPI-Info" ofType:@"plist"];
  NSDictionary *plistDict = [NSDictionary dictionaryWithContentsOfFile:plistPath];

  NSString *apiKey = plistDict[@"NRAPIKey"];
  NSString *collectorAddress = plistDict[@"collectorAddress"];
  NSString *crashCollectorAddress = plistDict[@"crashCollectorAddress"];

  if (apiKey) {
    // Set platform as React Native
    [NewRelic setPlatform:NRMAPlatform_ReactNative];

    // Enable features like NRTestApp
    [NewRelic enableFeatures:NRFeatureFlag_NewEventSystem];
    [NewRelic enableFeatures:NRFeatureFlag_OfflineStorage];

    // Configure event pool and buffer (like NRTestApp)
    [NewRelic setMaxEventPoolSize:5000];
    [NewRelic setMaxEventBufferTime:60];

    // Add HTTP header tracking
    [NewRelic addHTTPHeaderTrackingFor:@[@"X-Custom-Header"]];

    // Start the agent
    if (collectorAddress.length > 0 && crashCollectorAddress.length > 0) {
      [NewRelic startWithApplicationToken:apiKey
                        andCollectorAddress:collectorAddress
                   andCrashCollectorAddress:crashCollectorAddress];
    } else {
      [NewRelic startWithApplicationToken:apiKey];
    }

    // Set React Native version as attribute
    [NewRelic setAttribute:@"ReactNativeVersion" value:@"0.76.5"];
  }

  // Now initialize React Native
  self.moduleName = @"RNSampleApp";
  // You can add your custom initial props in the dictionary below.
  // They will be passed down to the ViewController used by React Native.
  self.initialProps = @{};

  return [super application:application didFinishLaunchingWithOptions:launchOptions];
}

- (NSURL *)sourceURLForBridge:(RCTBridge *)bridge
{
  return [self bundleURL];
}

- (NSURL *)bundleURL
{
#if DEBUG
  return [[RCTBundleURLProvider sharedSettings] jsBundleURLForBundleRoot:@"index"];
#else
  return [[NSBundle mainBundle] URLForResource:@"main" withExtension:@"jsbundle"];
#endif
}

@end
