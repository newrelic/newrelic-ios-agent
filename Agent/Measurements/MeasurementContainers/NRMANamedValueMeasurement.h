//
//  NRMANamedValueMeasurement.h
//  NewRelicAgent
//
//  Created by Bryce Buchanan on 9/30/13.
//  Copyright (c) 2013 New Relic. All rights reserved.
//

#import "NRMAMeasurement.h"

#ifdef __cplusplus
 extern "C" {
#endif

NS_ASSUME_NONNULL_BEGIN

@interface NRMANamedValueMeasurement : NRMAMeasurement
@property(strong, nonatomic) NSNumber* value;
@property(strong, nonatomic) NSString* scope;

@property(strong, nonatomic) NSNumber* __nullable additionalValue;

- (instancetype) initWithName:(NSString*)name
                        value:(NSNumber*)value
              additionalValue:(NSNumber* __nullable)additionalValue;

@end

NS_ASSUME_NONNULL_END

#ifdef __cplusplus
}
#endif
