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

- (nonnull instancetype) initWithEventType:(NSString *)eventType
                                 timestamp:(NSTimeInterval)timestamp
                                 accountID:(NSString*)accountId
                                 appID:(NSString*)appId
                                 ID:(NSString*)id
                                 traceID:(NSString*)traceId
                                 parentID:(NSString*)parentId
                                 trustedAccountKey:(NSString*)trustedAccountKey;

@end

NS_ASSUME_NONNULL_END
