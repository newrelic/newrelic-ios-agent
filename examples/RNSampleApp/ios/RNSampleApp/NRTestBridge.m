#import "NRTestBridge.h"
#import <NewRelic/NewRelic.h>

@implementation NRTestBridge

RCT_EXPORT_MODULE();

// MARK: - Attributes

RCT_EXPORT_METHOD(setAttribute:(NSString *)name value:(NSString *)value) {
    [NewRelic setAttribute:name value:value];
}

RCT_EXPORT_METHOD(setNumberAttribute:(NSString *)name value:(double)value) {
    [NewRelic setAttribute:name value:[NSNumber numberWithDouble:value]];
}

RCT_EXPORT_METHOD(setBoolAttribute:(NSString *)name value:(BOOL)value) {
    [NewRelic setAttribute:name value:value ? @YES : @NO];
}

RCT_EXPORT_METHOD(removeAttribute:(NSString *)name) {
    [NewRelic removeAttribute:name];
}

RCT_EXPORT_METHOD(removeAllAttributes) {
    [NewRelic removeAllAttributes];
}

RCT_EXPORT_METHOD(incrementAttribute:(NSString *)name value:(double)value) {
    [NewRelic incrementAttribute:name value:[NSNumber numberWithDouble:value]];
}

// MARK: - Custom Events

RCT_EXPORT_METHOD(recordCustomEvent:(NSString *)eventType
                  eventName:(NSString *)eventName
                  attributes:(NSDictionary *)attributes) {
    [NewRelic recordCustomEvent:eventType name:eventName attributes:attributes];
}

RCT_EXPORT_METHOD(recordBreadcrumb:(NSString *)name
                  attributes:(NSDictionary *)attributes) {
    [NewRelic recordBreadcrumb:name attributes:attributes];
}

// MARK: - Error Recording

RCT_EXPORT_METHOD(recordError:(NSString *)errorName
                  message:(NSString *)message
                  stack:(NSString *)stack
                  isFatal:(BOOL)isFatal) {

    NSString *truncatedStack = stack;
    if (stack.length > 3994) {
        truncatedStack = [stack substringToIndex:3994];
    }

    NSDictionary *attributes = @{
        @"Name": errorName ?: @"",
        @"Message": message ?: @"",
        @"errorStack": truncatedStack ?: @"",
        @"isFatal": @(isFatal)
    };

    [NewRelic recordBreadcrumb:@"JS Errors" attributes:attributes];
    [NewRelic recordCustomEvent:@"JS Errors" attributes:attributes];
}

// MARK: - Interactions

RCT_EXPORT_METHOD(startInteraction:(NSString *)interactionName
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject) {
    @try {
        NSString *interactionId = [NewRelic startInteractionWithName:interactionName];
        resolve(interactionId);
    } @catch (NSException *exception) {
        reject(@"ERROR", exception.reason, nil);
    }
}

RCT_EXPORT_METHOD(endInteraction:(NSString *)interactionId) {
    [NewRelic stopCurrentInteraction:interactionId];
}

// MARK: - Session

RCT_EXPORT_METHOD(currentSessionId:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject) {
    @try {
        NSString *sessionId = [NewRelic currentSessionId];
        resolve(sessionId);
    } @catch (NSException *exception) {
        reject(@"ERROR", exception.reason, nil);
    }
}

// MARK: - Network

RCT_EXPORT_METHOD(noticeHttpTransaction:(NSString *)url
                  httpMethod:(NSString *)httpMethod
                  statusCode:(NSInteger)statusCode
                  startTime:(double)startTime
                  endTime:(double)endTime
                  bytesSent:(NSInteger)bytesSent
                  bytesReceived:(NSInteger)bytesReceived
                  responseBody:(NSString *)responseBody) {

    NSURL *nsurl = [NSURL URLWithString:url];
    NSData *data = [responseBody dataUsingEncoding:NSUTF8StringEncoding];

    [NewRelic noticeNetworkRequestForURL:nsurl
                              httpMethod:httpMethod
                               startTime:startTime
                                 endTime:endTime
                         responseHeaders:nil
                              statusCode:statusCode
                               bytesSent:bytesSent
                           bytesReceived:bytesReceived
                            responseData:data
                            traceHeaders:nil
                               andParams:nil];
}

// MARK: - Utility

RCT_EXPORT_METHOD(crashNow:(NSString *)message) {
    if (message.length > 0) {
        [NewRelic crashNow:message];
    } else {
        [NewRelic crashNow];
    }
}

RCT_EXPORT_METHOD(setUserId:(NSString *)userId) {
    [NewRelic setUserId:userId];
}

RCT_EXPORT_METHOD(setMaxEventPoolSize:(NSNumber *)size) {
    [NewRelic setMaxEventPoolSize:size.unsignedIntValue];
}

RCT_EXPORT_METHOD(setMaxEventBufferTime:(NSNumber *)seconds) {
    [NewRelic setMaxEventBufferTime:seconds.unsignedIntValue];
}

// MARK: - Test Helper

RCT_EXPORT_METHOD(ping:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject) {
    resolve(@{
        @"status": @"Bridge is working!",
        @"timestamp": @([[NSDate date] timeIntervalSince1970])
    });
}

@end
