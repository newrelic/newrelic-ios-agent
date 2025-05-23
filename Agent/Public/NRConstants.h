//
// NRConstants
// NewRelic
//
//  New Relic for Mobile -- iOS edition
//
//  See:
//    https://docs.newrelic.com/docs/mobile-monitoring for information
//    https://docs.newrelic.com/docs/release-notes/mobile-release-notes/xcframework-release-notes/ for release notes
//
//  Copyright © 2023 New Relic. All rights reserved.
//  See https://docs.newrelic.com/docs/licenses/ios-agent-licenses for license details
//

#import <Foundation/Foundation.h>
#ifndef __NRCONSTANTS_H
#define __NRCONSTANTS_H
#ifdef __cplusplus
extern "C" {
#endif


// NRMAApplicationPlatform is an enum defining a list of possible
// platforms used to build the application.
    typedef NS_ENUM(NSUInteger, NRMAApplicationPlatform) {
        NRMAPlatform_Native,
        NRMAPlatform_Cordova,
        NRMAPlatform_PhoneGap,
        NRMAPlatform_Xamarin,
        NRMAPlatform_Unity,
        NRMAPlatform_Appcelerator,
        NRMAPlatform_ReactNative,
        NRMAPlatform_Flutter,
        NRMAPlatform_Capacitor,
        NRMAPlatform_MAUI,
        NRMAPlatform_Unreal
    };

// these constants are paired with enum values of NRMAApplicationPlatform
// they are used to convert the enum value to a human readable name.
// to update these values, look to NewRelicInternalUtils.m to add additional
// translations.
#define kNRMAPlatformString_Native       @"Native"
#define kNRMAPlatformString_Cordova      @"Cordova"
#define kNRMAPlatformString_PhoneGap     @"PhoneGap"
#define kNRMAPlatformString_Xamarin      @"Xamarin"
#define kNRMAPlatformString_Unity        @"Unity"
#define kNRMAPlatformString_Appcelerator @"Appcelerator"
#define kNRMAPlatformString_ReactNative  @"ReactNative"
#define kNRMAPlatformString_Flutter      @"Flutter"
#define kNRMAPlatformString_Capacitor    @"Capacitor"
#define kNRMAPlatformString_MAUI         @"MAUI"
#define kNRMAPlatformString_Unreal       @"Unreal"


//Custom Trace Types
enum NRTraceType {
    NRTraceTypeNone,
    NRTraceTypeViewLoading,
    NRTraceTypeLayout,
    NRTraceTypeDatabase,
    NRTraceTypeImages,
    NRTraceTypeJson,
    NRTraceTypeNetwork
};



#define X_APP_LICENSE_KEY_REQUEST_HEADER        @"X-App-License-Key"

#define kNRNetworkStatusDidChangeNotification @"com.newrelic.networkstatus.changed"
#define kNRCarrierNameDidUpdateNotification   @"com.newrelic.carrierName.changed"
#define kNRMemoryUsageDidChangeNotification   @"com.newrelic.memoryusage.changed"

#define kNRMAAnalyticsInitializedNotification @"com.newrelic.analytics.initialized"
#define kNRMAAnalyticsControllerKey           @"AnalyticsController"


//Unique installs/upgrades
#define kNRMADidGenerateNewUDIDNotification   @"com.newrelic.UDID.new"

#define kNRMAVendorIDAttribute                @"nr.vendorID"

#define kNRMASecureUDIDIsNilNotification      @"com.newrelic.SecureUDID.returnedNil"
#define kNRMANoSecureUDIDAttribute            @"nr.noSecureUDID"
#define kNRMAAppInstallMetric                 @"Mobile/App/Install"
#define kNRMADeviceChangedAttribute           @"nr.deviceDidChange"

#define kNRMADidChangeAppVersionNotification  @"com.newrelic.app.version.change"
#define kNRMADeviceDidChangeNotification      @"com.newrelic.device.didChange"

#define kNRMAAppUpgradeMetric                 @"Mobile/App/Upgrade"
#define kNRMALastVersionKey                   @"lastVersion"
#define kNRMACurrentVersionKey                @"currentVersion"
    
//Custom Metric Units
typedef NSString NRMetricUnit;

#define kNRMetricUnitPercent            (NRMetricUnit*)@"%"
#define kNRMetricUnitBytes              (NRMetricUnit*)@"bytes"
#define kNRMetricUnitSeconds            (NRMetricUnit*)@"sec"
#define kNRMetricUnitsBytesPerSecond    (NRMetricUnit*)(@"bytes/second")
#define kNRMetricUnitsOperations        (NRMetricUnit*)@"op"



#define kNRMASecondsPerMillisecond      0.001

//Metrics Constants
#define kNRSupportabilityPrefix          @"Supportability/MobileAgent"
#define kNRMAMetricActivityNetworkPrefix @"Mobile/Activity/Network"
#define kNRAgentHealthPrefix             @"Supportability/AgentHealth"
#define kNRMASessionStartMetric          @"Session/Start"

// NativePlatform, Platform,
#define kNRMAStopAgentMetricFormatString @"Supportability/Mobile/%@/%@/API/shutdown"

#define kNRMAUUIDOverridden              @"Supportability/Mobile/iOS/UUID/Overridden"

// Defines Format string where 4 arguments are NativePlatform, Platform, Destination and DestinationSubArea.
#define kNRMABytesOutSupportabilityFormatString  @"Supportability/Mobile/%@/%@/%@/%@/Output/Bytes"
// Defines Format string where 3 arguments are NativePlatform, Platform, and Destination.
#define kNRMABytesOutSupportabilityRollUpFormatString  @"Supportability/Mobile/%@/%@/%@/Output/Bytes"

// Defines Format string where 4 arguments are NativePlatform, Platform, Destination and Endpoint.
#define kNRMAMaxPayloadSizeLimitSupportabilityFormatString  @"Supportability/Mobile/%@/%@/%@/MaxPayloadSizeLimit/%@"
#define kNRMAMaxPayloadSizeLimit         1000000 // bytes
#define kNRMAMaxLogPayloadSizeLimit      700000 // bytes

#define kNRMAOfflineSupportabilityFormatString  @"Supportability/Mobile/%@/%@/%@/OfflinePayload/bytes"

#define kNRMABytesOutConnectAPIString     @"/connect/Output/Bytes"
#define kNRMABytesOutDataAPIString        @"/data/Output/Bytes"
#define kNRMABytesOutFAPIString           @"/f/Output/Bytes"
#define kNRMABytesOutMobileCrashAPIString @"/mobile_crash/Output/Bytes"

#define kNRSupportabilityDistributedTracing @"Supportability/TraceContext"

#define kNRMAMetricSuffixCount           @"Count"
#define kNRMAMetricSuffixTime            @"Time"

#define kNRMAExceptionHandlerHijackedMetric kNRAgentHealthPrefix @"/Hijacked/ExceptionHandler"

#define kNRMAConfigurationUpdated        @"Supportability/Mobile/%@/%@/Configuration/Updated"

//Network info cache constants
#define kNRCarrierNameCacheLifetime     50 // milliseconds
#define kNRWanTypeCacheLifetime         25 // milliseconds
#define kNRNetworkStatusCacheLifetime   25 // milliseconds

// UserActions
#define kNRMAUserActionAppLaunch        @"AppLaunch"
#define kNRMAUserActionAppBackground    @"AppBackground"
#define kNRMAUserActionTap              @"Tap"

#define kNRDeviceIDReplacementMaxLength 40

#define kNRMAContentEncodingHeader      @"Content-Encoding"
#define kNRMAGZipHeader                 @"deflate"
#define kNRMAIdentityHeader             @"identity"
#define kNRMAActualSizeHeader           @"actual-size"
#define kNRMACollectorDest              @"Collector"

#define kPlatformPlaceholder            @"[PLATFORM]"
#define NRMA_METRIC_APP_LAUNCH_COLD        @"AppLaunch/Cold"
#define NRMA_METRIC_APP_LAUNCH_RESUME      @"AppLaunch/Hot"

// Logging
#define kNRMALoggingMetric kNRAgentHealthPrefix @"/%@/%@/LogReporting"
#define kNRMALoggingMetricFailedUpload    kNRMALoggingMetric @"/FailedUpload"
#define kNRMALoggingMetricSuccessfulSize    kNRMALoggingMetric @"/Size/Uncompressed"

#define NRMAHandledRequestKey @"NRMAHandledRequest"

// Network Failure Codes
enum NRNetworkFailureCode {
        NRURLErrorUnknown = -1,
        NRURLErrorCancelled = -999,
        NRURLErrorBadURL = -1000,
        NRURLErrorTimedOut = -1001,
        NRURLErrorUnsupportedURL = -1002,
        NRURLErrorCannotFindHost = -1003,
        NRURLErrorCannotConnectToHost = -1004,
        NRURLErrorDataLengthExceedsMaximum = -1103,
        NRURLErrorNetworkConnectionLost = -1005,
        NRURLErrorDNSLookupFailed = -1006,
        NRURLErrorHTTPTooManyRedirects = -1007,
        NRURLErrorResourceUnavailable = -1008,
        NRURLErrorNotConnectedToInternet = -1009,
        NRURLErrorRedirectToNonExistentLocation = -1010,
        NRURLErrorBadServerResponse = -1011,
        NRURLErrorUserCancelledAuthentication = -1012,
        NRURLErrorUserAuthenticationRequired = -1013,
        NRURLErrorZeroByteResource = -1014,
        NRURLErrorCannotDecodeRawData = -1015,
        NRURLErrorCannotDecodeContentData = -1016,
        NRURLErrorCannotParseResponse = -1017,
        NRURLErrorInternationalRoamingOff = -1018,
        NRURLErrorCallIsActive = -1019,
        NRURLErrorDataNotAllowed = -1020,
        NRURLErrorRequestBodyStreamExhausted = -1021,
        NRURLErrorFileDoesNotExist = -1100,
        NRURLErrorFileIsDirectory = -1101,
        NRURLErrorNoPermissionsToReadFile = -1102,
        NRURLErrorSecureConnectionFailed = -1200,
        NRURLErrorServerCertificateHasBadDate = -1201,
        NRURLErrorServerCertificateUntrusted = -1202,
        NRURLErrorServerCertificateHasUnknownRoot = -1203,
        NRURLErrorServerCertificateNotYetValid = -1204,
        NRURLErrorClientCertificateRejected = -1205,
        NRURLErrorClientCertificateRequired = -1206,
        NRURLErrorCannotLoadFromNetwork = -2000,
        NRURLErrorCannotCreateFile = -3000,
        NRURLErrorCannotOpenFile = -3001,
        NRURLErrorCannotCloseFile = -3002,
        NRURLErrorCannotWriteToFile = -3003,
        NRURLErrorCannotRemoveFile = -3004,
        NRURLErrorCannotMoveFile = -3005,
        NRURLErrorDownloadDecodingFailedMidStream = -3006,
        NRURLErrorDownloadDecodingFailedToComplete = -3007
};


#ifdef __cplusplus
}
#endif
#endif
