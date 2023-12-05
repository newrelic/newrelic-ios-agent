//
//  NRMASAM.h
//  NewRelicAgent
//
//  Created by Chris Dillard on 7/26/23.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "BlockAttributeValidator.h"

NS_ASSUME_NONNULL_BEGIN

@interface NRMASAM : NSObject

- (id)initWithAttributeValidator:(__nullable id<AttributeValidatorProtocol>) validator;

- (BOOL) setSessionAttribute:(NSString*)name value:(id)value;
- (BOOL) setNRSessionAttribute:(NSString*)name value:(id)value;

- (BOOL) incrementSessionAttribute:(NSString*)name value:(NSNumber*)number;
- (BOOL) setUserId:(NSString*)userId;
- (BOOL) removeSessionAttributeNamed:(NSString*)name;
- (BOOL) removeAllSessionAttributes;

+ (NSString*) getLastSessionsAttributes;
- (void) clearLastSessionsAnalytics;

- (NSString*) sessionAttributeJSONString;
- (BOOL) setLastInteraction:(NSString*)name;

+ (void) clearDuplicationStores;
@end

NS_ASSUME_NONNULL_END
