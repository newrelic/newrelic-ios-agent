//
//  NRMAHarvestResponse.h
//  NewRelicAgent
//
//  Created by Bryce Buchanan on 8/27/13.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>



#define OK                     200
#define UNAUTHORIZED           401
#define FORBIDDEN              403
#define NOT_FOUND              404
#define CONFIGURATION_UPDATE   409
#define ENTITY_TOO_LARGE       413
#define URL_TOO_LARGE          414
#define INVALID_AGENT_ID       450
#define UNSUPPORTED_MEDIA_TYPE 415
#define TOO_MANY_REQUESTS      429
#define UNKNOWN                 -1
#define ZERO_STATUS_CODE         0

@interface NRMAHarvestResponse : NSObject
{
    NSString* _responseBody;
}
@property(assign) int statusCode;
@property(strong) NSString* responseBody;
@property(strong) NSError* error;
// Parsed value of the Retry-After response header in seconds; 0 when absent or unparseable.
@property(assign) NSTimeInterval retryAfterSeconds;

- (int) getResponseCode;
- (BOOL) isDisableCommand;
- (BOOL) isError;
- (BOOL) isOK;
- (BOOL) isRateLimited;

// Parses the Retry-After header (delta-seconds or HTTP-date) into retryAfterSeconds.
- (void) parseRetryAfterFromHeaders:(NSDictionary*)headers;

@end
