//
//  NRMAMobileErrorsUploader.h
//  NewRelicAgent
//
//  Created by New Relic Mobile Agent Team
//  Copyright © 2025 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NRMAMobileErrorsUploader : NSObject<NSURLSessionDelegate, NSURLSessionDataDelegate>

- (instancetype) initWithHost:(NSString*)host
             applicationToken:(NSString*)applicationToken
                   appVersion:(NSString*)appVersion
                       useSSL:(BOOL)useSSL;

/// Send error payload to /mobile/errors endpoint
- (void) sendPayload:(NSDictionary*)payload
           sessionId:(NSString* _Nullable)sessionId
          entityGuid:(NSString* _Nullable)entityGuid
           accountId:(NSNumber* _Nullable)accountId
    trustedAccountId:(NSNumber* _Nullable)trustedAccountId
        sessionToken:(NSString* _Nullable)sessionToken
    agentConfigToken:(NSString* _Nullable)agentConfigToken;

/// Retry failed uploads
- (void) retryFailedUploads;

/// Invalidate the session and cancel all tasks
- (void) invalidate;

@end

NS_ASSUME_NONNULL_END
