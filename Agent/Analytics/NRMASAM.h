//
//  NRMASAM.h
//  Agent
//
//  Created by Steve Malsam on 8/10/23.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NRMASAM : NSObject

- (BOOL) setSessionAttribute:(NSString *)name value:(id)value;

- (BOOL) removeSessionAttributeNamed:(NSString *)name;
- (void) removeAllSessionAttributes;

- (nullable NSString *)getSessionAttributeJSONStringWithError:( NSError * _Nullable *)error;

@end

NS_ASSUME_NONNULL_END
