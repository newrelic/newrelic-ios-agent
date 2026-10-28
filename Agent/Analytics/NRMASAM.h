//
//  NRMASAM.h
//  NewRelicAgent
//
//  Created by Chris Dillard on 7/26/23.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "BlockAttributeValidator.h"
#import "PersistentEventStore.h"

NS_ASSUME_NONNULL_BEGIN

@interface NRMASAM : NSObject

- (id)initWithAttributeValidator:(__nullable id<AttributeValidatorProtocol>) validator;

- (BOOL) setSessionAttribute:(NSString*)name value:(id)value;
- (BOOL) setNRSessionAttribute:(NSString*)name value:(id)value;

- (BOOL) incrementSessionAttribute:(NSString*)name value:(NSNumber*)number;
- (BOOL) setUserId:(NSString*)userId;
- (BOOL) removeSessionAttributeNamed:(NSString*)name;
- (BOOL) removeNRSessionAttributeNamed:(NSString*)name;
- (BOOL) removeAllSessionAttributes;

+ (NSString*) getLastSessionsAttributes;

- (NSString*) sessionAttributeJSONString;
- (BOOL) setLastInteraction:(NSString*)name;

// Private "NR" attributes only (os/device/app version, carrier, etc.) --
// used as the "stableAttributes" captured in a session's persisted manifest.
- (NSDictionary*) currentPrivateAttributes;
@end

NS_ASSUME_NONNULL_END
