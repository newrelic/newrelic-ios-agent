//
// Created by Bryce Buchanan on 12/8/15.
// Copyright © 2023 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NRMAUDIDManager : NSObject
+ (NSString*) deviceIdentifier;
+ (NSString*) UDID;
+ (void) deleteStoredID;

@end
