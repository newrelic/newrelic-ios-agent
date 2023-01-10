//
//  NRMAMeasurementException.h
//  NewRelicAgent
//
//  Created by Bryce Buchanan on 8/20/13.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>
#ifdef __cplusplus
extern "C" {
#endif

#define NRMAFinishedMeasurementEditedException @"FinishedMeasurementEditedException"
#define NRMAMeasurementTypeConsistencyError @"MeasurementTypeConsistencyError"
#define NRMAMeasurementActivityException @"NRMAMeasurementActivityException"

@interface NRMAMeasurementException : NSException
- (id) initWithName:(NSString *)aName
             reason:(NSString *)aReason
           userInfo:(NSDictionary *)aUserInfo;
@end

#ifdef __cplusplus
}
#endif
