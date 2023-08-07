//
//  NRMASAM.h
//  NewRelicAgent
//
//  Created by Chris Dillard on 7/26/23.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "BlockAttributeValidator.h"

@interface NRMASAM : NSObject

- (id)initWithAttributeValidator:(BlockAttributeValidator*) validator;

- (BOOL) setSessionAttribute:(NSString*)name value:(id)value persistent:(BOOL)isPersistent;
- (BOOL) setNRSessionAttribute:(NSString*)name value:(id)value;

- (BOOL) incrementSessionAttribute:(NSString*)name value:(NSNumber*)number persistent:(BOOL)persistent;
- (BOOL) setUserId:(NSString*)userId;
- (BOOL) removeSessionAttributeNamed:(NSString*)name;
- (BOOL) removeAllSessionAttributes;

+ (NSString*) getLastSessionsAttributes;
- (void) clearLastSessionsAnalytics;
- (void) clearPersistedSessionAnalytics;

- (NSString*) sessionAttributeJSONString;
- (BOOL) setLastInteraction:(NSString*)name;
@end
