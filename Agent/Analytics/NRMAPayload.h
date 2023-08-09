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
@property  NSTimeInterval timestamp;
@property (nonatomic, strong) NSString *payloadType;
@property (nonatomic, strong) NSString *accountId;
@property (nonatomic, strong) NSString *appId;
@property (nonatomic, strong) NSString *id;
@property (nonatomic, strong) NSString *traceId;
@property (nonatomic, strong) NSString *parentId;
@property (nonatomic, strong) NSString *trustedAccountKey;
@property  bool dtEnabled;

- (nonnull instancetype) initWithTimestamp:(NSTimeInterval)timestamp
                                 accountID:(NSString*)accountId
                                 appID:(NSString*)appId
                                 traceID:(NSString*)traceId
                                 parentID:(NSString*)parentId
                                 trustedAccountKey:(NSString*)trustedAccountKey;

@end

NS_ASSUME_NONNULL_END
