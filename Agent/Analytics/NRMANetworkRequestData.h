//
//  Copyright © 2023 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NRMANetworkRequestData : NSObject

@property (nonatomic, retain) NSString *requestUrl;
@property (nonatomic, retain) NSString *requestDomain;
@property (nonatomic, retain) NSString *requestPath;
@property (nonatomic, retain) NSString *requestMethod;
@property (nonatomic, retain) NSString *connectionType;
@property (nonatomic, retain) NSString *contentType;
@property (nonatomic) NSInteger bytesSent;
@property (nonatomic, retain) NSDictionary *trackedHeaders;

-(id) initWithRequestUrl:(NSURL*)requestUrl
              httpMethod:(NSString*)requestMethod
          connectionType:(NSString*)connectionType
             contentType:(NSString*)contentType
               bytesSent:(NSInteger)bytesSent;

-(void) dealloc;

@end
