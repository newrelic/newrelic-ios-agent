//
//  Copyright © 2023 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NRMANetworkRequestData : NSObject

@property (nonatomic) NSString *requestUrl;
@property (nonatomic) NSString *requestDomain;
@property (nonatomic) NSString *requestPath;
@property (nonatomic) NSString *requestMethod;
@property (nonatomic) NSString *connectionType;
@property (nonatomic) NSString *contentType;
@property (nonatomic) NSInteger bytesSent;
@property (nonatomic) NSDictionary *trackedHeaders;

-(id) initWithRequestUrl:(NSURL*)requestUrl
              httpMethod:(NSString*)requestMethod
          connectionType:(NSString*)connectionType
             contentType:(NSString*)contentType
               bytesSent:(NSInteger)bytesSent;

-(void) dealloc;

@end
