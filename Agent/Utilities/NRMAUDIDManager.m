//
// Created by Bryce Buchanan on 12/8/15.
// Copyright © 2023 New Relic. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "NRMAUDIDManager.h"
#import "NRMAUUIDStore.h"
#import "NRConstants.h"
#import "NRMAMeasurements.h"
#import "NRMAFlags.h"
#import <CommonCrypto/CommonCrypto.h>

#if TARGET_OS_WATCH
#import <WatchKit/WatchKit.h>
#endif

static NSString* const kNRMASecureUDIDStore = @"com.newrelic.secureUDID";
static NSString* const kNRMAVendorIDStore   = @"com.newrelic.vendorID";

@implementation NRMAUDIDManager

+ (NSString*) deviceIdentifier {
//    return ![NRMAFlags shouldReplaceDeviceIdentifier] ? [UIDevice currentDevice].identifierForVendor.UUIDString : [NRMAFlags replacementDeviceIdentifier];
#if !TARGET_OS_WATCH
    NSString* vendorId = [UIDevice currentDevice].identifierForVendor.UUIDString;
#elif TARGET_OS_WATCH
    NSString* vendorId = [WKInterfaceDevice currentDevice].identifierForVendor.UUIDString;
#endif
    return ![NRMAFlags shouldReplaceDeviceIdentifier] ? vendorId : [NRMAFlags replacementDeviceIdentifier];
}

+ (NSString*) UDID {
    NSString* udid = [NRMAUDIDManager getUDID];
    if (!udid) {
        @synchronized(self) {
            udid = [NRMAUDIDManager getUDID];
            if (udid == nil) {
                udid = [self noSecureUDIDFile];
                [NRMAUDIDManager setUDID:udid];
            }
        }
    }
    return udid;
}
static __strong NSString* __UDID;
+ (void) setUDID:(NSString*)udid {
    @synchronized(__UDID) {
        __UDID = udid ;
    }
}

+ (NSString*) getUDID {
    @synchronized(__UDID) {
        return __UDID;
    }
}
+ (NRMAUUIDStore*) secureUDIDStore {
    static NRMAUUIDStore* __secureUDIDStore;
    if (!__secureUDIDStore) {
        __secureUDIDStore = [[NRMAUUIDStore alloc] initWithFilename:kNRMASecureUDIDStore];
    }
    return __secureUDIDStore;
}

+ (NRMAUUIDStore*) identifierForVendorStore {
    static NRMAUUIDStore* __identifierForVendorStore;
    if (!__identifierForVendorStore) {
        __identifierForVendorStore = [[NRMAUUIDStore alloc] initWithFilename:kNRMAVendorIDStore];
    }
    return __identifierForVendorStore;
}

+ (NSString*) getSystemIdentifier {
    if ([NRMAFlags shouldSaltDeviceUUID]) {
        // We use app ID as salt. This will prevent apps across bundle Ids sharing device Ids.
        NSString* clearStr = [[NRMAUDIDManager saltValue] stringByAppendingString:[NRMAUDIDManager deviceIdentifier]];
        NSString *output = [NRMAUDIDManager sha256Hash:clearStr];
        return output;
    } else {
        return [NRMAUDIDManager deviceIdentifier];
    }
}

+ (NSString*)sha256Hash:(NSString*)text {
    const char* chars = [text UTF8String];
    unsigned char result[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(chars, (CC_LONG)strlen(chars), result);
    NSMutableString *ret = [NSMutableString stringWithCapacity:CC_SHA256_DIGEST_LENGTH*2];
    for(int i = 0; i<CC_SHA256_DIGEST_LENGTH; i++) {
        [ret appendFormat:@"%02x",result[i]];
    }
    return ret;
}

+ (NSString*) saltValue {
    return [[NSBundle mainBundle] infoDictionary][@"CFBundleExecutable"];
}

+ (NSString*) noSecureUDIDFile {
    NSString* identifierForVendor = [NRMAUDIDManager getSystemIdentifier];
    if ([[NRMAUDIDManager identifierForVendorStore] storedUUID]) {
        if(identifierForVendor.length) {
            if(![[[NRMAUDIDManager identifierForVendorStore] storedUUID] isEqualToString:identifierForVendor]){
                //the identifier for vendor has changed!
                [[NRMAUDIDManager identifierForVendorStore] storeUUID:identifierForVendor];
                [[NSNotificationCenter defaultCenter] postNotificationName:kNRMADidGenerateNewUDIDNotification
                                                                    object:nil
                                                                  userInfo:@{ @"UDID" : identifierForVendor }];
                return identifierForVendor;
            }
        }
        return [[NRMAUDIDManager identifierForVendorStore] storedUUID];
    } else {
        
        [[NSNotificationCenter defaultCenter] postNotificationName:kNRMASecureUDIDIsNilNotification object:nil];
        // NEW INSTALL.
        if (identifierForVendor.length) {
            [[NRMAUDIDManager identifierForVendorStore] storeUUID:identifierForVendor];
            [[NSNotificationCenter defaultCenter] postNotificationName:kNRMADidGenerateNewUDIDNotification
                                                                object:nil
                                                              userInfo:@{ @"UDID" : identifierForVendor }];
            return identifierForVendor;
        } else {
            
            [NRMAMeasurements recordAndScopeMetricNamed:[NSString stringWithFormat:@"%@/%@/%@", kNRAgentHealthPrefix, @"DeviceIdentifier", @"GeneratedUDID"]
                                                  value:@1];
            
            CFUUIDRef uuid = CFUUIDCreate(kCFAllocatorDefault);
            NSString* identifier = ![NRMAFlags shouldReplaceDeviceIdentifier] ? (NSString*)CFBridgingRelease(CFUUIDCreateString(kCFAllocatorDefault, uuid)) : [NRMAUDIDManager deviceIdentifier];
            CFRelease(uuid);
            
            [[NSNotificationCenter defaultCenter] postNotificationName:kNRMADidGenerateNewUDIDNotification
                                                                object:nil
                                                              userInfo:@{ @"UDID" : identifier }];
            
            [[NRMAUDIDManager secureUDIDStore] storeUUID:identifier];
            return identifier;
        }
    }
}

+ (void) deleteStoredID {
    [[self identifierForVendorStore] removeStore];
}

@end
