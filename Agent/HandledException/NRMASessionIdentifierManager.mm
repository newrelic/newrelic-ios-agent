//
// Created by Bryce Buchanan on 7/24/17.
// Copyright © 2023 New Relic. All rights reserved.
//

//#import "NRMASessionIdentifierManager.h"
//
//#define kNRMA_SESSION_ID_KEY @"NewRelicSessionIdentifier"
//
//@interface NRMASessionIdentifierManager ()
//@property(strong) NSString* identifier;
//@end
//
//@implementation NRMASessionIdentifierManager
//
//- (NSString*) sessionIdentifier {
//    if (self.identifier) return self.identifier;
//
//    self.identifier = [[NSUserDefaults standardUserDefaults] objectForKey:kNRMA_SESSION_ID_KEY];
//
//    if(self.identifier) return self.identifier;
//
//    self.identifier = [[NSUUID UUID] UUIDString];
//
//    [self storeIdentifier:self.identifier];
//
//    return self.identifier;
//}
//
//- (void) storeIdentifier:(NSString*)uuid {
//    [[NSUserDefaults standardUserDefaults] setObject:uuid
//                                              forKey:kNRMA_SESSION_ID_KEY];
//    [[NSUserDefaults standardUserDefaults] synchronize];
//}
//
//// Function included for testing.
//+ (void) purge {
//    [[NSUserDefaults standardUserDefaults] setObject:nil
//                                              forKey:kNRMA_SESSION_ID_KEY];
//    [[NSUserDefaults standardUserDefaults] synchronize];
//}
//@end
