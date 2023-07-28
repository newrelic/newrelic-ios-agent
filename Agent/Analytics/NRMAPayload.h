//
//  NRMAPayload.h
//  Agent
//
//  Created by Mike Bruin on 7/26/23.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import "NRMAAnalyticEventProtocol.h"
#import "AttributeValidatorProtocol.h"

NS_ASSUME_NONNULL_BEGIN

@interface NRMAPayload : NSObject <NRMAJSONABLE>
@property (readonly) NSTimeInterval timestamp;
@property (nonatomic, readonly) NSString *eventType;
@property (nonatomic, readonly) NSString *accountId;
@property (nonatomic, readonly) NSString *appId;
@property (nonatomic, readonly) NSString *id;
@property (nonatomic, readonly) NSString *traceId;
@property (nonatomic, readonly) NSString *parentId;
@property (nonatomic, readonly) NSString *trustedAccountKey;
@property (readonly) bool dtEnabled;

@end

NS_ASSUME_NONNULL_END
