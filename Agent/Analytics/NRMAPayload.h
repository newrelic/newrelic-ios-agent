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
@property (nonatomic) NSString *payloadType;
@property (nonatomic) NSString *accountId;
@property (nonatomic) NSString *appId;
@property (nonatomic) NSString *id;
@property (nonatomic) NSString *traceId;
@property (nonatomic) NSString *parentId;
@property (nonatomic) NSString *trustedAccountKey;
@property  bool dtEnabled;

- (nonnull instancetype) initWithTimestamp:(NSTimeInterval)timestamp
                                 accountID:(NSString*)accountId
                                 appID:(NSString*)appId
                                 ID:(NSString*)id
                                 traceID:(NSString*)traceId
                                 parentID:(NSString*)parentId
                                 trustedAccountKey:(NSString*)trustedAccountKey;

@end

NS_ASSUME_NONNULL_END
