//  Copyright © 2023 New Relic. All rights reserved.

#import "NRMAAnalytics.h"
#import "NRMAAnalytics+cppInterface.h"
#import "NRMALoggerBridge.hpp"

#import "NRLogger.h"
#import "NRMAHarvestableAnalytics.h"
#import <iomanip>
#import <exception>
#import <libkern/OSAtomic.h>
#import "NRMAHarvestController.h"
#import "NRMABool.h"
#import <Utilities/LibLogger.hpp>
#import "NRConstants.h"
#import "NewRelicInternalUtils.h"
#import "NRMAFlags.h"
#import "NRMANetworkRequestData+CppInterface.h"
#import "NRMANetworkResponseData+CppInterface.h"
#import "NRMAUserActionBuilder.h"
#import <Connectivity/Payload.hpp>
#import "NewRelicAgentInternal.h"
#import "NRMAEventManager.h"

#import "Constants.h"
#import "NRMAEventManager.h"
#import "NRMACustomEvent.h"
#import "NRMARequestEvent.h"
#import "NRMAPayload.h"
#import "NRMANetworkErrorEvent.h"
#import "NRMASAM.h"
#import "BlockAttributeValidator.h"
#import "NRMAAnalyticsConstants.h"

//#define USE_INTEGRATED_EVENT_MANAGER 0

using namespace NewRelic;
@implementation NRMAAnalytics
{
    std::shared_ptr<AnalyticsController> _analyticsController;
    BOOL _sessionWillEnd;
    NSRegularExpression* __eventTypeRegex;
    
    NRMAEventManager *_eventManager;
    NRMASAM *_sessionAttributeManager;
    NSDate *_sessionStartTime;
}

static PersistentStore<std::string,BaseValue>* __attributeStore;
+ (PersistentStore<std::string, BaseValue> &) attributeDupStore
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
    __attributeStore = new PersistentStore<std::string,BaseValue>{AnalyticsController::getAttributeDupStoreName(), [NewRelicInternalUtils getStorePath].UTF8String, &NewRelic::Value::createValue};
    });

    return (*__attributeStore);
}

static PersistentStore<std::string,AnalyticEvent>* __eventStore;
+ (PersistentStore<std::string, AnalyticEvent> &) eventDupStore
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        __eventStore = new PersistentStore<std::string,AnalyticEvent>{AnalyticsController::getEventDupStoreName(),
                                                                     [NewRelicInternalUtils getStorePath].UTF8String,
                                                                     &NewRelic::EventManager::newEvent,
                                                                     [](std::string const& key, std::shared_ptr<AnalyticEvent> event){
                                                                        return key == EventManager::createKey(event) ;
                                                                     }};
    });
    return (*__eventStore);
}   

- (std::shared_ptr<NewRelic::AnalyticsController>&) analyticsController {
    return _analyticsController;
}

- (void) setMaxEventBufferSize:(unsigned int) size {
    _analyticsController->setMaxEventBufferSize(size);
}
- (void) setMaxEventBufferTime:(unsigned int)seconds
{
    _analyticsController->setMaxEventBufferTime(seconds);
}

- (id) initWithSessionStartTimeMS:(long long) sessionStartTime {
    self = [super init];
    if(self){
        if(!__has_feature(cxx_exceptions)) {
            NRLOG_ERROR(@"C++ exception handling is disabled. This will cause incorrect behavior in the New Relic Agent.");
            @throw [NSException exceptionWithName:@"Invalid Configuration" reason:@"c++ exception handling is disabled" userInfo:nil];
        }

        NSString* documentDirURL = [NewRelicInternalUtils getStorePath];
        LibLogger::setLogger(std::make_shared<NewRelic::NRMALoggerBridge>(NewRelic::NRMALoggerBridge()));
        _analyticsController = std::make_shared<NewRelic::AnalyticsController>(sessionStartTime,documentDirURL.UTF8String, [NRMAAnalytics eventDupStore], [NRMAAnalytics attributeDupStore]);
        //__kNRMA_RA_upgradeFrom and __kNRMA_RA_install are only valid for one session
        //and will be set shortly after the initialization of NRMAAnalytics.
        //They can be removed now and it shouldn't interfere with the generation
        //of these attributes if it should occur.
        NSString* attributes = [self sessionAttributeJSONString];
        if (attributes != nil) {
            NSDictionary* dictionary = [NSJSONSerialization JSONObjectWithData:[attributes dataUsingEncoding:NSUTF8StringEncoding]
                                                                       options:0
                                                                         error:nil];
            if (dictionary[@(__kNRMA_RA_upgradeFrom)]) {
                _analyticsController->removeSessionAttribute(__kNRMA_RA_upgradeFrom);
            }
            if (dictionary[@(kNRMASecureUDIDIsNilNotification.UTF8String)]) {
                _analyticsController->removeSessionAttribute(kNRMASecureUDIDIsNilNotification.UTF8String);
            }
            if (dictionary[@(kNRMADeviceChangedAttribute.UTF8String)]) {
                _analyticsController->removeSessionAttribute(kNRMADeviceChangedAttribute.UTF8String);
            }
            if (dictionary[@(__kNRMA_RA_install)]) {
                _analyticsController->removeSessionAttribute(__kNRMA_RA_install);
            }
            
            //session duration is only valid for one session. This metric should be removed
            //after the persistent attributes are loaded.   
            if (dictionary[@(__kNRMA_RA_sessionDuration)]) {
                _analyticsController->removeSessionAttribute(__kNRMA_RA_sessionDuration);
            }
        }
        
#if USE_INTEGRATED_EVENT_MANAGER
        _eventManager = [NRMAEventManager new];
        _sessionAttributeManager = [[NRMASAM alloc] initWithAttributeValidator:[[BlockAttributeValidator alloc] initWithNameValidator:^BOOL(NSString *name) {
            if ([name length] == 0) {
                NRLOG_ERROR(@"invalid attribute: name length = 0");
                return false;
            }
            if ([name hasPrefix:@" "]) {
                NRLOG_ERROR(@"invalid attribute: name prefix = \" \"");
                return false;
            }
            // check if attribute name is reserved or attribute name matches reserved prefix.
            for (NSString* key in reservedKeywords) {
                if ([key isEqualToString:name]) {
                    NRLOG_ERROR(@"invalid attribute: name prefix disallowed");
                    return false;
                }
                if ([name hasPrefix:key])  {
                    NRLOG_ERROR(@"invalid attribute: name prefix disallowed");
                    return false;
                }
            }
            // check if attribute name exceeds max length.
            if ([name length] > maxNameLength) {
                NRLOG_ERROR(@"invalid attribute: name length exceeds limit");
                return false;
            }
            return true;
            
        } valueValidator:^BOOL(id value) {
            if ([value isKindOfClass:[NSString class]]) {
                if ([(NSString*)value length] == 0) {
                    NRLOG_ERROR(@"invalid attribute: value length = 0");
                    return false;
                }
                else if ([(NSString*)value length] >= maxValueSizeBytes) {
                    NRLOG_ERROR(@"invalid attribute: value exceeded maximum byte size exceeded");
                    return false;
                }
            }
            if (value == nil) {
                NRLOG_ERROR(@"invalid attribute: value cannot be nil");
                return false;
            }

            return true;
        } andEventTypeValidator:^BOOL(NSString *eventType) {
            return YES;
        }]];
#endif
        // SessionStartTime is passed in as milliseconds. In the agent, when used,
        // the NSDate time interval is multiplied by 1000 to get milliseconds.
        // Tests will pass it in as 0, hence the check.
        // When libMobileAgent finally goes away, this can simply be initialized with the NSDate
        // the NewRelicAgentInternal initializes with.
        if(sessionStartTime == 0) {
            _sessionStartTime = [NSDate dateWithTimeIntervalSince1970:sessionStartTime];
        } else {
            _sessionStartTime = [NSDate dateWithTimeIntervalSince1970:(sessionStartTime/1000)];
        }
    }
    return self;
}

- (void) dealloc {
    [__eventTypeRegex release];

    [super dealloc];
}

- (BOOL) addInteractionEvent:(NSString*)name
         interactionDuration:(double)duration_secs {
    return _analyticsController->addInteractionEvent([name UTF8String], duration_secs);
}
#if USE_INTEGRATED_EVENT_MANAGER
- (BOOL) addNetworkRequestEvent:(NRMANetworkRequestData *)requestData
                  withResponse:(NRMANetworkResponseData *)responseData
               withPayload:(NRMAPayload *)payload {
    if ([NRMAFlags shouldEnableNetworkRequestEvents]) {
        return [self addRequestEvent:requestData withResponse:responseData withPayload:payload];
    }
    return NO;
}

- (BOOL)addRequestEvent:(NRMANetworkRequestData *)requestData
           withResponse:(NRMANetworkResponseData *)responseData
            withPayload:(NRMAPayload *)payload {

    @try {
        NSString* distributedTracingId = @"";
        NSString* traceId = @"";
        bool addDistributedTracing = false;
        if (payload != nil) {
            distributedTracingId = payload.id;
            traceId = payload.traceId;
            addDistributedTracing = payload.dtEnabled;
        }
        
        NSTimeInterval currentTime_ms = [[[NSDate alloc] init] timeIntervalSince1970];
        NSTimeInterval sessionDuration_sec = [[NSDate date] timeIntervalSinceDate:_sessionStartTime];
        
        NRMARequestEvent *event = [[NRMARequestEvent alloc] initWithTimestamp:currentTime_ms sessionElapsedTimeInSeconds:sessionDuration_sec payload:payload withAttributeValidator:nil]; //TODO: need a real AttributeValidator?
        if (event == nil) {
            return false;
        }
        
        NSString* requestUrl = requestData.requestUrl;
        NSString* requestDomain = requestData.requestDomain;
        NSString* requestPath = requestData.requestPath;
        NSString* requestMethod = requestData.requestMethod;
        NSString* connectionType = requestData.connectionType;
        NSNumber* bytesSent = @(requestData.bytesSent);
        NSString* contentType = requestData.contentType;
        NSNumber *responseTime = @(responseData.timeInSeconds);
        NSNumber* bytesReceived = @(responseData.bytesReceived);
        NSNumber* statusCode = @(responseData.statusCode);
        
        if ((requestUrl.length == 0)) {
            NRLOG_WARNING(@"Unable to add NetworkEvent with empty URL.");
            return false;
        }
        
        [event addAttribute:kNRMA_Attrib_requestUrl value:requestUrl];
        [event addAttribute:kNRMA_Attrib_responseTime value:responseTime];
        
        if (addDistributedTracing) {
            [event addAttribute:kNRMA_Attrib_dtGuid value:distributedTracingId];
            [event addAttribute:kNRMA_Attrib_dtId value:distributedTracingId];
            [event addAttribute:kNRMA_Attrib_dtTraceId value:traceId];
            [event addAttribute:kNRMA_Attrib_traceId value:traceId];
        }
        
        if ((requestDomain.length > 0)) {
            [event addAttribute:kNRMA_Attrib_requestDomain value:requestDomain];
        }
        
        if ((requestPath.length > 0)) {
            [event addAttribute:kNRMA_Attrib_requestPath value:requestPath];
        }
        
        if ((requestMethod.length > 0)) {
            [event addAttribute:kNRMA_Attrib_requestMethod value:requestMethod];
        }
        
        if ((connectionType.length > 0)) {
            [event addAttribute:kNRMA_Attrib_connectionType value:connectionType];
        }
        
        if (![bytesReceived isEqual: @(0)]) {
            [event addAttribute:kNRMA_Attrib_bytesReceived value:bytesReceived];
        }
        
        if (![bytesSent isEqual: @(0)]) {
            [event addAttribute:kNRMA_Attrib_bytesSent value:bytesSent];
        }
        
        if (![statusCode isEqual: @(0)]) {
            [event addAttribute:kNRMA_Attrib_statusCode value:statusCode];
        }
        
        if ((contentType.length > 0)) {
            [event addAttribute:kNRMA_Attrib_contentType value:contentType];
        }
        
        return [_eventManager addEvent:event];
    } @catch (NSException *exception) {
        NRLOG_ERROR(@"Failed to add Network Event.: %@", exception.reason);
    }
}

- (BOOL)addNetworkErrorEvent:(NRMANetworkRequestData *)requestData
                withResponse:(NRMANetworkResponseData *)responseData
                 withPayload:(NRMAPayload*)payload {
    if ([NRMAFlags shouldEnableRequestErrorEvents]) {
        NRMANetworkErrorEvent *event = (NRMANetworkErrorEvent*)[self createErrorEvent:requestData withResponse:responseData withPayload:payload];
        if(event == nil){ return NO; }
        [event addAttribute:kNRMA_Attrib_errorType value:kNRMA_Val_errorType_Network];
            
        return [_eventManager addEvent:event];
    }
    return NO;
}

- (BOOL) addHTTPErrorEvent:(NRMANetworkRequestData *)requestData
            withResponse:(NRMANetworkResponseData *)responseData
            withPayload:(NRMAPayload *)payload {
    if ([NRMAFlags shouldEnableRequestErrorEvents]) {
        NRMANetworkErrorEvent *event = (NRMANetworkErrorEvent*)[self createErrorEvent:requestData withResponse:responseData withPayload:payload];
        if(event == nil){ return NO; }
        [event addAttribute:kNRMA_Attrib_errorType value:kNRMA_Val_errorType_HTTP];

        return [_eventManager addEvent:event];
    }
    return NO;
}

- (id<NRMAAnalyticEventProtocol>)createErrorEvent:(NRMANetworkRequestData *)requestData
           withResponse:(NRMANetworkResponseData *)responseData
             withPayload:(NRMAPayload *)payload {
    @try {
        NSString* distributedTracingId = @"";
        NSString* traceId = @"";
        bool addDistributedTracing = false;
        if (payload != nil) {
            distributedTracingId = payload.id;
            traceId = payload.traceId;
            addDistributedTracing = payload.dtEnabled;
        }
        
        NSTimeInterval currentTime_ms = [[[NSDate alloc] init] timeIntervalSince1970];
        NSTimeInterval sessionDuration_sec = [[NSDate date] timeIntervalSinceDate:_sessionStartTime];
        
        NSString* requestUrl = requestData.requestUrl;
        NSString* requestDomain = requestData.requestDomain;
        NSString* requestPath = requestData.requestPath;
        NSString* requestMethod = requestData.requestMethod;
        NSString* connectionType = requestData.connectionType;
        NSNumber* bytesSent = @(requestData.bytesSent);
        NSString* contentType = requestData.contentType;
        NSString* appDataHeader = responseData.appDataHeader;
        NSString* encodedResponseBody = responseData.encodedResponseBody;
        NSString* networkErrorMessage = responseData.errorMessage;
        NSNumber* networkErrorCode = @(responseData.networkErrorCode);
        NSNumber *responseTime = @(responseData.timeInSeconds);
        NSNumber* bytesReceived = @(responseData.bytesReceived);
        NSNumber* statusCode = @(responseData.statusCode);
        
        if ((requestUrl.length == 0)) {
            NRLOG_WARNING(@"Unable to add NetworkEvent with empty URL.");
            return nil;
        }
        
        NRMANetworkErrorEvent *event = [[NRMANetworkErrorEvent alloc] initWithTimestamp:currentTime_ms sessionElapsedTimeInSeconds:sessionDuration_sec encodedResponseBody:encodedResponseBody appDataHeader:appDataHeader payload:payload withAttributeValidator:nil]; //TODO: need a real AttributeValidator?
        if (event == nil) {
            return nil;
        }
        
        [event addAttribute:kNRMA_Attrib_requestUrl value:requestUrl];
        [event addAttribute:kNRMA_Attrib_responseTime value:responseTime];
        
        if (addDistributedTracing) {
            [event addAttribute:kNRMA_Attrib_dtGuid value:distributedTracingId];
            [event addAttribute:kNRMA_Attrib_dtId value:distributedTracingId];
            [event addAttribute:kNRMA_Attrib_dtTraceId value:traceId];
        }
        
        if ((requestDomain.length > 0)) {
            [event addAttribute:kNRMA_Attrib_requestDomain value:requestDomain];
        }
        
        if ((requestPath.length > 0)) {
            [event addAttribute:kNRMA_Attrib_requestPath value:requestPath];
        }
        
        if ((requestMethod.length > 0)) {
            [event addAttribute:kNRMA_Attrib_requestMethod value:requestMethod];
        }
        
        if ((connectionType.length > 0)) {
            [event addAttribute:kNRMA_Attrib_connectionType value:connectionType];
        }
        
        if (![bytesReceived isEqual: @(0)]) {
            [event addAttribute:kNRMA_Attrib_bytesReceived value:bytesReceived];
        }
        
        if (![bytesSent isEqual: @(0)]) {
            [event addAttribute:kNRMA_Attrib_bytesSent value:bytesSent];
        }
        
        if (encodedResponseBody.length > 0) {
            [event addAttribute:kNRMA_Attrib_networkError value:networkErrorMessage];
        }
        
        if (![networkErrorCode isEqual: @(0)]) {
            [event addAttribute:kNRMA_Attrib_networkErrorCode value:networkErrorCode];
        }
        
        if (networkErrorMessage.length > 0) {
            [event addAttribute:kNRMA_Attrib_networkError value:networkErrorMessage];
        }
        
        if (![statusCode isEqual: @(0)]) {
            [event addAttribute:kNRMA_Attrib_statusCode value:statusCode];
        }
        
        if ((contentType.length > 0)) {
            [event addAttribute:kNRMA_Attrib_contentType value:contentType];
        }
        
        return event;
    } @catch (NSException *exception) {
        NRLOG_ERROR(@"Failed to add Network Event.: %@", exception.reason);
    }
}

#else

- (BOOL)addNetworkRequestEvent:(NRMANetworkRequestData *)requestData
                  withResponse:(NRMANetworkResponseData *)responseData
                   withPayload:(std::unique_ptr<const Connectivity::Payload>)payload {
    if ([NRMAFlags shouldEnableNetworkRequestEvents]) {
        NewRelic::NetworkRequestData* networkRequestData = [requestData getNetworkRequestData];
        NewRelic::NetworkResponseData* networkResponseData = [responseData getNetworkResponseData];
        return _analyticsController->addRequestEvent(*networkRequestData, *networkResponseData, std::move(payload));
    }
    return NO;
}

- (BOOL)addNetworkErrorEvent:(NRMANetworkRequestData *)requestData
                withResponse:(NRMANetworkResponseData *)responseData
                 withPayload:(std::unique_ptr<const NewRelic::Connectivity::Payload>)payload {
    if ([NRMAFlags shouldEnableRequestErrorEvents]) {
        NewRelic::NetworkRequestData* networkRequestData = [requestData getNetworkRequestData];
        NewRelic::NetworkResponseData* networkResponseData = [responseData getNetworkResponseData];

        return _analyticsController->addNetworkErrorEvent(*networkRequestData, *networkResponseData,std::move(payload));
    }

    return NO;
}

- (BOOL)addHTTPErrorEvent:(NRMANetworkRequestData *)requestData
             withResponse:(NRMANetworkResponseData *)responseData
            withPayload:(std::unique_ptr<const NewRelic::Connectivity::Payload>)payload {
    if ([NRMAFlags shouldEnableRequestErrorEvents]) {
        NewRelic::NetworkRequestData* networkRequestData = [requestData getNetworkRequestData];
        NewRelic::NetworkResponseData* networkResponseData = [responseData getNetworkResponseData];

        return _analyticsController->addHTTPErrorEvent(*networkRequestData, *networkResponseData, std::move(payload));
    }
    return NO;
}
#endif

- (BOOL) setLastInteraction:(NSString*)name {
#if USE_INTEGRATED_EVENT_MANAGER
    return [_sessionAttributeManager setLastInteraction:name];
#else
    return [self setNRSessionAttribute:kNRMA_RA_lastInteraction
                                 value:name];
#endif
}

- (BOOL) setNRSessionAttribute:(NSString*)name value:(id)value {
#if USE_INTEGRATED_EVENT_MANAGER
    return [_sessionAttributeManager setNRSessionAttribute:name value:value];
#else
    try {
        if ([value isKindOfClass:[NSNumber class]]) {
            NSNumber* number = (NSNumber*)value;
            if ([NewRelicInternalUtils isFloat:number]) {
                auto attribute = NewRelic::Attribute<float>::createAttribute([name UTF8String],
                                                                             [](const char* name_str) {
                                                                                 return strlen(name_str) > 0;
                                                                             },
                                                                             [number floatValue],
                                                                             [](float num) {
                                                                                 return true;
                                                                             });

                return _analyticsController->addNRAttribute(attribute);
            }
            if ([NewRelicInternalUtils isInteger:number]) {
                auto attribute = NewRelic::Attribute<long long>::createAttribute([name UTF8String],
                                                                             [](const char* name_str) {
                                                                                 return strlen(name_str) > 0;
                                                                             },
                                                                             [number longLongValue],
                                                                             [](long long num) {
                                                                                 return true;
                                                                             });
                return _analyticsController->addNRAttribute(attribute);
            }
            return NO;
        } else if ([value isKindOfClass:[NSString class]]) {
            NSString* string = (NSString*)value;
            auto attribute = NewRelic::Attribute<const char*>::createAttribute([name UTF8String], [](const char* name_str) {
                return strlen(name_str) > 0;
            }, [string UTF8String], [](const char* value_str) {
                return strlen(value_str) > 0;
            });
            return _analyticsController->addNRAttribute(attribute);
        } else if([value isKindOfClass:[NRMABool class]]) {
                auto attribute = NewRelic::Attribute<bool>::createAttribute([name UTF8String],
                                                                            [](const char* name_str) {return strlen(name_str) > 0;},
                                                                            ((NRMABool*)value).value,
                                                                            [](bool) { return true;});
                return _analyticsController->addNRAttribute(attribute);
        } else {
            NRLOG_VERBOSE(@"Session attribute \'value\' must be either an NSString* or NSNumber*");
            return NO;
        }
    } catch (std::exception& error) {
        NRLOG_VERBOSE(@"failed to add NR session attribute, \'%@\' : %s",name, error.what());
        return NO;
    } catch (...) {
        NRLOG_VERBOSE(@"failed to add NR session attribute.");
        return NO;

    }
#endif
}

- (BOOL) setSessionAttribute:(NSString*)name value:(id)value persistent:(BOOL)isPersistent {
#if USE_INTEGRATED_EVENT_MANAGER
    return [_sessionAttributeManager setSessionAttribute:name value:value persistent:isPersistent];
#else
    try {
        if ([value isKindOfClass:[NSNumber class]]) {
            NSNumber* number = (NSNumber*)value;
            //objcType returns a char*, but all primitives are denoted by a single character
            if([NewRelicInternalUtils isInteger:number]) {
                return _analyticsController->addSessionAttribute([name UTF8String], [number longLongValue], (bool)isPersistent);
            }
            if([NewRelicInternalUtils isFloat:number]) {
                return _analyticsController->addSessionAttribute([name UTF8String], [number doubleValue], (bool)isPersistent);
            }
            if ([NewRelicInternalUtils isBool:number]) {
                return _analyticsController->addSessionAttribute([name UTF8String], (bool)[number boolValue], (bool)isPersistent);
            }
            return NO;
        } else if ([value isKindOfClass:[NSString class]]) {
            NSString* string = (NSString*)value;
            return _analyticsController->addSessionAttribute([name UTF8String], [string UTF8String],(bool)isPersistent);
        } else if([value isKindOfClass:[NRMABool class]]) {
                auto attribute = NewRelic::Attribute<bool>::createAttribute([name UTF8String],
                                                                            [](const char* name_str) {return strlen(name_str) > 0;},
                                                                            ((NRMABool*)value).value,
                                                                            [](bool) { return true;});
                return _analyticsController->addNRAttribute(attribute);
        } else {
            NRLOG_ERROR(@"Session attribute \'value\' must be either an NSString* or NSNumber*");
            return NO;
        }
    } catch (std::exception& error) {
        NRLOG_ERROR(@"failed to add session attribute: \'%@\': %s",name ,error.what());
        return NO;
    } catch (...) {
        NRLOG_ERROR(@"failed to add session attribute.");
        return NO;

    }
#endif
}

- (BOOL) setSessionAttribute:(NSString*)name value:(id)value {
#if USE_INTEGRATED_EVENT_MANAGER
    return [_sessionAttributeManager setSessionAttribute:name value:value persistent:true];
#else
    try {
        if ([value isKindOfClass:[NSNumber class]]) {
            NSNumber* number = (NSNumber*)value;
            if([NewRelicInternalUtils isInteger:number]) {
                return _analyticsController->addSessionAttribute([name UTF8String], [number longLongValue]);
            }
            if([NewRelicInternalUtils isFloat:number]) {
                return _analyticsController->addSessionAttribute([name UTF8String], [number doubleValue]);
            }
            return NO;
        } else if ([value isKindOfClass:[NSString class]]) {
            NSString* string = (NSString*)value;
            return _analyticsController->addSessionAttribute([name UTF8String], [string UTF8String]);
        } else if([value isKindOfClass:[NRMABool class]]) {
                auto attribute = NewRelic::Attribute<bool>::createAttribute([name UTF8String],
                                                                            [](const char* name_str) {return strlen(name_str) > 0;},
                                                                            ((NRMABool*)value).value,
                                                                            [](bool) { return true;});
                return _analyticsController->addNRAttribute(attribute);
        } else {
            NRLOG_ERROR(@"Session attribute \'value\' must be either an NSString* or NSNumber*");
            return NO;
        }
    } catch (std::exception& error) {
        NRLOG_ERROR(@"failed to add session attribute: \'%@\': %s",name ,error.what());
        return NO;
    } catch (...) {
        NRLOG_ERROR(@"failed to add session attribute.");
        return NO;

    }
#endif
}

- (BOOL) setUserId:(NSString *)userId {
#if USE_INTEGRATED_EVENT_MANAGER
    return [_sessionAttributeManager setUserId:userId];
#else
    return [self setSessionAttribute:@"userId"
                               value:userId
                          persistent:YES];
#endif
}

- (BOOL) removeSessionAttributeNamed:(NSString*)name {
#if USE_INTEGRATED_EVENT_MANAGER
    return [_sessionAttributeManager removeSessionAttributeNamed:name];
#else
    try {
        return _analyticsController->removeSessionAttribute(name.UTF8String);
    } catch (std::exception& e) {
        NRLOG_ERROR(@"Failed to remove attribute: %s",e.what());
        return NO;
    } catch (...) {
        NRLOG_ERROR(@"Failed to remove attribute.");
        return NO;
    }
#endif
}
- (BOOL) removeAllSessionAttributes {
#if USE_INTEGRATED_EVENT_MANAGER
    return [_sessionAttributeManager removeAllSessionAttributes];
#else
    try {
        return _analyticsController->clearSessionAttributes();
    } catch (std::exception& e) {
        NRLOG_ERROR(@"Failed to remove all attributes: %s",e.what());
        return NO;
    } catch (...) {
        NRLOG_ERROR(@"Failed to remove all attributes.");
        return NO;

    }
#endif
}

- (BOOL) addEventNamed:(NSString*)name withAttributes:(NSDictionary*)attributes {
#if USE_INTEGRATED_EVENT_MANAGER
    NRMACustomEvent *testEvent = [[NRMACustomEvent alloc] initWithEventType:name
                                                                  timestamp:[[NSDate date] timeIntervalSince1970]
                                                                  sessionElapsedTimeInSeconds:[[NSDate date] timeIntervalSinceDate:_sessionStartTime]
                                                                  withAttributeValidator:nil];
    [attributes enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        [testEvent addAttribute:key value:obj];
    }];
    
    return [_eventManager addEvent:testEvent];
#else
    try {
        auto event = _analyticsController->newEvent(name.UTF8String);
        if (event == nullptr) {
            NRLOG_ERROR(@"Unable to create event with name: \"%@\"",name);
            return NO;
        }

        if ([self event:event withAttributes:attributes]) {
            return _analyticsController->addEvent(event);
        }
    } catch (std::exception& e){
        NRLOG_ERROR(@"Failed to add event: %s",e.what());
        return NO;
    } catch (...) {
        NRLOG_ERROR(@"Failed to add event named: %@.\nPossible due to reserved word conflict.",name);
        return NO;
    }
    return NO;
#endif
}

- (BOOL) addBreadcrumb:(NSString*)name
        withAttributes:(NSDictionary*)attributes {
#if USE_INTEGRATED_EVENT_MANAGER
    return NO;
#else
    try {

        if(!name.length) {
            NRLOG_ERROR(@"Breadcrumb must be named.");
            return NO;
        }

        auto event = _analyticsController->newBreadcrumbEvent();
        if (event == nullptr) {
            NRLOG_ERROR(@"Unable to create breadcrumb event");
            return NO;
        }

        if ([self event:event withAttributes:attributes]) {
                event->addAttribute("name",name.UTF8String);
            return _analyticsController->addEvent(event);
        }
    } catch (std::exception& e){
        NRLOG_ERROR(@"Failed to add event: %s",e.what());
        return NO;
    } catch (...) {
        NRLOG_ERROR(@"Failed to add event named: %@.\nPossible due to reserved word conflict.",name);
        return NO;
    }
    return NO;
#endif
}


- (BOOL) addCustomEvent:(NSString*)eventType
         withAttributes:(NSDictionary*)attributes {
    try {
        if (!__eventTypeRegex) {
            NSError* error = nil;
            __eventTypeRegex = [[NSRegularExpression alloc] initWithPattern:@"^[\\p{L}\\p{Nd} _:.]+$"
                                                                     options:NSRegularExpressionUseUnicodeWordBoundaries
                                                                       error:&error];
            if (error != nil) {
                NRLOG_ERROR(@"addCustomEvent failed with error: %@",error);
                return false;
            }
        }

        NSArray* textCheckingResults = [__eventTypeRegex matchesInString:eventType
                                                                 options:NSMatchingReportCompletion
                                                                   range:NSMakeRange(0, eventType.length)];

        if (!(textCheckingResults.count > 0 && ((NSTextCheckingResult*)textCheckingResults[0]).range.length == eventType.length)) {
            NRLOG_ERROR(@"Failed to add event type: %@. EventType is may only contain word characters, numbers, spaces, colons, underscores, and periods.",eventType);
            return NO;
        }

#if USE_INTEGRATED_EVENT_MANAGER
        NRMACustomEvent* event = [[NRMACustomEvent alloc] initWithEventType:eventType
                                                                  timestamp:[[NSDate date] timeIntervalSince1970]
                                                sessionElapsedTimeInSeconds:[[NSDate date] timeIntervalSinceDate:_sessionStartTime] withAttributeValidator:nil];
        [attributes enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
            [event addAttribute:key value:obj];
        }];
        [_eventManager addEvent:event];
        
        return YES;
#else
        auto event = _analyticsController->newCustomEvent(eventType.UTF8String);

        if (event == nullptr) {
            NRLOG_ERROR(@"Unable to create event with name: \"%@\"",eventType);
            return NO;
        }

        if([self event:event withAttributes:attributes]) {
            return _analyticsController->addEvent(event);
        }
#endif
    } catch (std::exception& e){
        NRLOG_ERROR(@"Failed to add event: %s",e.what());
        return NO;
    } catch (...) {
        NRLOG_ERROR(@"Failed to add event named: %@.\nPossible due to reserved word conflict.",eventType);
        return NO;
    }
    return NO;
}

- (BOOL) event:(std::shared_ptr<AnalyticEvent>)event withAttributes:(NSDictionary*)attributes {
#if USE_INTEGRATED_EVENT_MANAGER
    return YES;
#else
    for (NSString* key in attributes.allKeys) {
        id value = attributes[key];
        if ([value isKindOfClass:[NSString class]]) {
            event->addAttribute(key.UTF8String,((NSString*)value).UTF8String);
        } else if ([value isKindOfClass:[NSNumber class]]) {
            NSNumber* number = (NSNumber*)value;
            if ([NewRelicInternalUtils isInteger:number]) {
                event->addAttribute(key.UTF8String, number.longLongValue);
            } else if ([NewRelicInternalUtils isFloat:number]) {
                event->addAttribute(key.UTF8String, number.doubleValue);
            } else if ([NewRelicInternalUtils isBool:number]) {
                event->addAttribute(key.UTF8String,number.boolValue);
            } else {
                NRLOG_ERROR(@"Failed to add attribute \"%@\" value is invalid NSNumber with objCType: %s",key,[number objCType]);
            }
        } else if([value isKindOfClass:[NRMABool class]]) {
            event->addAttribute(key.UTF8String, (bool)((NRMABool*)value).value);
        } else {
            NRLOG_ERROR(@"Failed to add attribute values must be type NSNumber* or NSString*.");
        }
    }
    return YES;
#endif
}

- (BOOL) incrementSessionAttribute:(NSString*)name value:(NSNumber*)number
{
#if USE_INTEGRATED_EVENT_MANAGER
    return [_sessionAttributeManager incrementSessionAttribute:name value:number persistent: false];
#else
    if ([NewRelicInternalUtils isInteger:number]) {
    return _analyticsController->incrementSessionAttribute([name UTF8String], (unsigned long long)[number longLongValue]); //has internal exception handling
    } else if ([NewRelicInternalUtils isFloat:number]) {
        return _analyticsController->incrementSessionAttribute([name UTF8String], [number doubleValue]); //has internal exception handling
    } else {
        return NO;
    }
#endif
}

- (BOOL) incrementSessionAttribute:(NSString*)name value:(NSNumber*)number persistent:(BOOL)persistent {
#if USE_INTEGRATED_EVENT_MANAGER
    return [_sessionAttributeManager incrementSessionAttribute:name value:number persistent:persistent];
#else
    if ([NewRelicInternalUtils isInteger:number]) {
        return _analyticsController->incrementSessionAttribute([name UTF8String], (unsigned long long)[number integerValue],(bool)persistent); //has internal exception handling.
    } else if ([NewRelicInternalUtils isFloat:number]) {
    return _analyticsController->incrementSessionAttribute([name UTF8String], [number floatValue],(bool)persistent); //has internal exception handling.
    } else {
        return NO;
    }
#endif
}



- (NSString*) analyticsJSONString {
#if USE_INTEGRATED_EVENT_MANAGER
    NSError *error = nil;
    return [_eventManager getEventJSONStringWithError:&error];
#else
    try {
        auto events = _analyticsController->getEventsJSON(true);
        std::stringstream stream;
        stream <<std::setprecision(13)<< *events;
        return [NSString stringWithUTF8String:stream.str().c_str()];
    } catch (std::exception& e) {
        NRLOG_VERBOSE(@"Failed to generate event json: %s",e.what());
    } catch (...) {
        NRLOG_VERBOSE(@"Failed to generate event json");
    }
    return nil;
#endif
}

- (NSString*) sessionAttributeJSONString {
#if USE_INTEGRATED_EVENT_MANAGER
    return [_sessionAttributeManager sessionAttributeJSONString];
#else
    try {
    auto attributes = _analyticsController->getSessionAttributeJSON();
    std::stringstream stream;
    stream <<std::setprecision(13)<<*attributes;
    return [NSString stringWithUTF8String:stream.str().c_str()];
    } catch (std::exception& e) {
        NRLOG_VERBOSE(@"Failed to generate attributes json: %s",e.what());
    } catch (...) {
        NRLOG_VERBOSE(@ "Failed to generate attributes json.");
    }
    return nil;
#endif
}
+ (NSString*) getLastSessionsAttributes {
#if USE_INTEGRATED_EVENT_MANAGER
    return [NRMASAM getLastSessionsAttributes];
#else
    try {
    auto attributes = AnalyticsController::fetchDuplicatedAttributes([self attributeDupStore], YES);
    std::stringstream stream;
    stream << std::setprecision(13)<< *attributes;
    
    NSString* jsonString = [NSString stringWithUTF8String:stream.str().c_str()];
    if (!jsonString.length) {
        return nil;
    }
        return jsonString;
    } catch (std::exception& e) {
        NRLOG_VERBOSE(@"failed to generate session attribute json: %s", e.what());
    } catch (...) {
        NRLOG_VERBOSE(@"failed to generate session attribute json.");
    }
    return nil;
#endif
}
+ (NSString*) getLastSessionsEvents{
    try {
        auto events = AnalyticsController::fetchDuplicatedEvents([self eventDupStore], true);
        std::stringstream stream;
        stream << std::setprecision(13) << *events;
        
        NSString* jsonString = [NSString stringWithUTF8String:stream.str().c_str()];
        
        if (!jsonString.length) {
            return nil;
        }
        
        return jsonString;
    } catch (std::exception& e) {
        NRLOG_VERBOSE(@"Failed to fetch event dup store: %s",e.what());
        
    } catch (...) {
        NRLOG_VERBOSE(@"Failed to fetch event dup store.");
    }

    return nil;
    
}

+ (void) clearDuplicationStores
{
#if USE_INTEGRATED_EVENT_MANAGER
    // TODO: SAM Persistence
//    [self attributeDupStore].clear();
//    [self eventDupStore].clear();
#else
    try {
        [self attributeDupStore].clear();
        [self eventDupStore].clear();
    } catch (std::exception& e) {
        NRLOG_VERBOSE(@"Failed to clear dup stores: %s",e.what());
    } catch(...) {
        NRLOG_VERBOSE(@"Failed to clear dup stores.");
    }
#endif
}


- (void) clearLastSessionsAnalytics {
#if USE_INTEGRATED_EVENT_MANAGER
    [_sessionAttributeManager clearLastSessionsAnalytics];
#else
    try {
        _analyticsController->clearAttributesDuplicationStore();
        _analyticsController->clearEventsDuplicationStore();
    } catch (std::exception& e) {
        NRLOG_VERBOSE(@"Failed to clear last sessions' analytcs, %s",e.what());
    } catch (...) {
        NRLOG_VERBOSE(@"Failed to clear last sessions' analytcs.");
    }
#endif
}

//Harvest Aware methods

- (void) sessionWillEnd {
    _sessionWillEnd = YES;
    
    if([NRMAFlags shouldEnableGestureInstrumentation])
    {
        NRMAUserAction* backgroundGesture = [NRMAUserActionBuilder buildWithBlock:^(NRMAUserActionBuilder *builder) {
            [builder withActionType:kNRMAUserActionAppBackground];
        }];
        [[NewRelicAgentInternal sharedInstance].gestureFacade recordUserAction:backgroundGesture];
    }
    
    if(!_analyticsController->addSessionEndAttribute()) { //has exception handling within
        NRLOG_ERROR(@"failed to add session end attribute.");
    }

    if(!_analyticsController->addSessionEvent()) { //has exception handling within
        NRLOG_ERROR(@"failed to add a session event");
    }
    
}

- (void) onHarvestBefore {
    if (_sessionWillEnd || _analyticsController->didReachMaxEventBufferTime()) {
        
        NRMAHarvestableAnalytics* harvestableAnalytics = [[NRMAHarvestableAnalytics alloc] initWithAttributeJSON:[self sessionAttributeJSONString]
                                                                                                        EventJSON:[self analyticsJSONString]];

        [NRMAHarvestController addHarvestableAnalytics:harvestableAnalytics];
        [harvestableAnalytics release];
    }
}
@end
