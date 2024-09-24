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
#import <Connectivity/Payload.hpp>
#import "NewRelicAgentInternal.h"
#import "NRMAEventManager.h"

#import "Constants.h"
#import "NRMAEventManager.h"
#import "NRMACustomEvent.h"
#import "NRMARequestEvent.h"
#import "NRMAInteractionEvent.h"
#import "NRMAPayload.h"
#import "NRMANetworkErrorEvent.h"
#import "NRMASAM.h"
#import "BlockAttributeValidator.h"
#import "NRMASessionEvent.h"

//******************* THIS FILE HAS ARC DISABLED *******************
// TODO: RE-ENABLE ARC WHEN THE C++ IS REMOVED

using namespace NewRelic;
@implementation NRMAAnalytics
{
    std::shared_ptr<AnalyticsController> _analyticsController;
    BOOL _sessionWillEnd;
    BOOL _newSession;

    NSRegularExpression* __eventTypeRegex;
    
    NRMAEventManager *_eventManager;
    NRMASAM *_sessionAttributeManager;
    NSDate *_sessionStartTime;
    id<AttributeValidatorProtocol> _attributeValidator;
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
    [NRMAAgentConfiguration setMaxEventBufferSize:size];
    if([NRMAFlags shouldEnableNewEventSystem]){
        [_eventManager setMaxEventBufferSize:size];
    }
    else {
        _analyticsController->setMaxEventBufferSize(size);
    }
}
- (NSUInteger) getMaxEventBufferSize {
    return [_eventManager getMaxEventBufferSize];
}
- (void) setMaxEventBufferTime:(unsigned int)seconds
{
    [NRMAAgentConfiguration setMaxEventBufferTime:seconds];
    if([NRMAFlags shouldEnableNewEventSystem]){
        [_eventManager setMaxEventBufferTimeInSeconds:seconds];
    }
    else {
        _analyticsController->setMaxEventBufferTime(seconds);
    }
}
- (NSUInteger) getMaxEventBufferTime {
    return [_eventManager getMaxEventBufferTimeInSeconds];
}

- (id) initWithSessionStartTimeMS:(long long) sessionStartTime {
    self = [super init];
    if(self){
        // Handle New Event System NRMAnalytics Constructor
        if([NRMAFlags shouldEnableNewEventSystem]){
            NSString *filename = [[NewRelicInternalUtils getStorePath] stringByAppendingPathComponent:kNRMA_EventStoreFilename];

            PersistentEventStore *eventStore = [[PersistentEventStore alloc] initWithFilename:filename andMinimumDelay:.025];
            
            _eventManager = [[NRMAEventManager alloc] initWithPersistentStore:eventStore];
            _attributeValidator = [[BlockAttributeValidator alloc] initWithNameValidator:^BOOL(NSString *name) {
                if ([name length] == 0) {
                    NRLOG_AGENT_ERROR(@"invalid attribute: name length = 0");
                    return false;
                }
                if ([name hasPrefix:@" "]) {
                    NRLOG_AGENT_ERROR(@"invalid attribute: name prefix = \" \"");
                    return false;
                }
                // check if attribute name is reserved or attribute name matches reserved prefix.
                for (NSString* key in [NRMAAnalytics reservedKeywords]) {
                    if ([key isEqualToString:name]) {
                        NRLOG_AGENT_ERROR(@"invalid attribute: name prefix disallowed");
                        return false;
                    }
                    if ([name hasPrefix:key])  {
                        NRLOG_AGENT_ERROR(@"invalid attribute: name prefix disallowed");
                        return false;
                    }
                }
                // check if attribute name exceeds max length.
                if ([name length] > kNRMA_Attrib_Max_Name_Length) {
                    NRLOG_AGENT_ERROR(@"invalid attribute: name length exceeds limit");
                    return false;
                }
                return true;
                
            } valueValidator:^BOOL(id value) {
                if ([value isKindOfClass:[NSString class]]) {
                    if ([(NSString*)value length] == 0) {
                        NRLOG_AGENT_ERROR(@"invalid attribute: value length = 0");
                        return false;
                    }
                    else if ([(NSString*)value length] >= kNRMA_Attrib_Max_Value_Size_Bytes) {
                        NRLOG_AGENT_ERROR(@"invalid attribute: value exceeded maximum byte size exceeded");
                        return false;
                    }
                }
                if (value == nil || [value isKindOfClass:[NSNull class]]) {
                    NRLOG_AGENT_ERROR(@"invalid attribute: value cannot be nil");
                    return false;
                }
                
                return true;
            } andEventTypeValidator:^BOOL(NSString *eventType) {
                return YES;
            }];
            _sessionAttributeManager = [[NRMASAM alloc] initWithAttributeValidator:_attributeValidator];


            NSString* attributes = [self sessionAttributeJSONString];
            if (attributes != nil && [attributes length] > 0) {
                NSDictionary* dictionary = [NSJSONSerialization JSONObjectWithData:[attributes dataUsingEncoding:NSUTF8StringEncoding]
                                                                           options:0
                                                                             error:nil];
                if (dictionary[kNRMA_RA_upgradeFrom]) {
                    [_sessionAttributeManager removeSessionAttributeNamed:kNRMA_RA_upgradeFrom];
                }
                if (dictionary[@(kNRMASecureUDIDIsNilNotification.UTF8String)]) {
                    [_sessionAttributeManager removeSessionAttributeNamed:kNRMASecureUDIDIsNilNotification];

                }
                if (dictionary[@(kNRMADeviceChangedAttribute.UTF8String)]) {
                    [_sessionAttributeManager removeSessionAttributeNamed:kNRMADeviceChangedAttribute];
                }
                if (dictionary[kNRMA_RA_install]) {
                    [_sessionAttributeManager removeSessionAttributeNamed:kNRMA_RA_install];
                }

                //session duration is only valid for one session. This metric should be removed
                //after the persistent attributes are loaded.
                if (dictionary[kNRMA_RA_sessionDuration]) {
                    [_sessionAttributeManager removeSessionAttributeNamed:kNRMA_RA_sessionDuration];
                }
            }
        }
        // Use old Event system
        else {
            if(!__has_feature(cxx_exceptions)) {
                NRLOG_AGENT_ERROR(@"C++ exception handling is disabled. This will cause incorrect behavior in the New Relic Agent.");
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
            if (attributes != nil && [attributes length] > 0) {
                NSDictionary* dictionary = [NSJSONSerialization JSONObjectWithData:[attributes dataUsingEncoding:NSUTF8StringEncoding]
                                                                           options:0
                                                                             error:nil];
                if (dictionary[kNRMA_RA_upgradeFrom]) {
                    _analyticsController->removeSessionAttribute([kNRMA_RA_upgradeFrom UTF8String]);
                }
                if (dictionary[@(kNRMASecureUDIDIsNilNotification.UTF8String)]) {
                    _analyticsController->removeSessionAttribute(kNRMASecureUDIDIsNilNotification.UTF8String);
                }
                if (dictionary[@(kNRMADeviceChangedAttribute.UTF8String)]) {
                    _analyticsController->removeSessionAttribute(kNRMADeviceChangedAttribute.UTF8String);
                }
                if (dictionary[kNRMA_RA_install]) {
                    _analyticsController->removeSessionAttribute([kNRMA_RA_install UTF8String]);
                }

                //session duration is only valid for one session. This metric should be removed
                //after the persistent attributes are loaded.
                if (dictionary[kNRMA_RA_sessionDuration]) {
                    _analyticsController->removeSessionAttribute([kNRMA_RA_sessionDuration UTF8String]);
                }
            }
        }
        // SessionStartTime is passed in as milliseconds. In the agent, when used,
        // the NSDate time interval is multiplied by 1000 to get milliseconds.
        // Tests will pass it in as 0, hence the check.
        // When libMobileAgent finally goes away, this can simply be initialized with the NSDate
        // the NewRelicAgentInternal initializes with.
        [self setSessionStartTime:sessionStartTime];
        [_sessionStartTime retain];
    }
    return self;
}

- (void)setSessionStartTime:(long long)sessionStartTime {
    if(sessionStartTime == 0) {
        _sessionStartTime = [NSDate dateWithTimeIntervalSince1970:sessionStartTime];
    } else {
        _sessionStartTime = [NSDate dateWithTimeIntervalSince1970:(sessionStartTime/1000)];
    }
}

- (void) dealloc {
    [__eventTypeRegex release];
    [_eventManager dealloc];
    [_sessionAttributeManager dealloc];
    [_attributeValidator release];
    [_sessionStartTime release];

    [super dealloc];
}

- (BOOL) addInteractionEvent:(NSString*)name
         interactionDuration:(double)duration_secs {
    if([NRMAFlags shouldEnableNewEventSystem]){
        if(name == nil || name.length == 0){return NO;}
        NRMAInteractionEvent *event = [[NRMAInteractionEvent alloc] initWithTimestamp:[NRMAAnalytics currentTimeMillis]
                                                sessionElapsedTimeInSeconds:[[NSDate date] timeIntervalSinceDate:_sessionStartTime] name:name category:@"Interaction"
                                                     withAttributeValidator:_attributeValidator];
        [event addAttribute:kNRMA_RA_InteractionDuration value:@(duration_secs)];
        
        return [_eventManager addEvent:[event autorelease]];
    } else {
        return _analyticsController->addInteractionEvent([name UTF8String], duration_secs, [self checkOfflineStatus], [self checkBackgroundStatus]);
    }
}

- (BOOL) addNetworkRequestEvent:(NRMANetworkRequestData *)requestData
                  withResponse:(NRMANetworkResponseData *)responseData
               withNRMAPayload:(NRMAPayload *)payload {
    if ([NRMAFlags shouldEnableNetworkRequestEvents]) {
        return [self addRequestEvent:requestData withResponse:responseData withNRMAPayload:payload];
    }
    return NO;
}

- (BOOL)addRequestEvent:(NRMANetworkRequestData *)requestData
           withResponse:(NRMANetworkResponseData *)responseData
            withNRMAPayload:(NRMAPayload *)payload {

    @try {
        NSString* distributedTracingId = @"";
        NSString* traceId = @"";
        bool addDistributedTracing = false;
        if (payload != nil) {
            distributedTracingId = payload.id;
            traceId = payload.traceId;
            addDistributedTracing = payload.dtEnabled;
        }
        
        NSTimeInterval sessionDuration_sec = [[NSDate date] timeIntervalSinceDate:_sessionStartTime];
        
        NRMARequestEvent *event = [[NRMARequestEvent alloc] initWithTimestamp:[NRMAAnalytics currentTimeMillis] sessionElapsedTimeInSeconds:sessionDuration_sec payload:payload withAttributeValidator:_attributeValidator];
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
        
        if (requestUrl.length == 0) {
            NRLOG_AGENT_WARNING(@"Unable to add NetworkEvent with empty URL.");
            return false;
        }
        
        [event addAttribute:kNRMA_Attrib_requestUrl value:requestUrl];
        [event addAttribute:kNRMA_Attrib_responseTime value:responseTime];
        
        if (addDistributedTracing) {
            if (distributedTracingId.length > 0) {
                [event addAttribute:kNRMA_Attrib_dtGuid value:distributedTracingId];
                [event addAttribute:kNRMA_Attrib_dtId value:distributedTracingId];
            }
            if (traceId.length > 0) {
                [event addAttribute:kNRMA_Attrib_dtTraceId value:traceId];
                [event addAttribute:kNRMA_Attrib_traceId value:traceId];
            }
        }
        
        if (requestDomain.length > 0) {
            [event addAttribute:kNRMA_Attrib_requestDomain value:requestDomain];
        }
        
        if (requestPath.length > 0) {
            [event addAttribute:kNRMA_Attrib_requestPath value:requestPath];
        }
        
        if (requestMethod.length > 0) {
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
        
        if (contentType.length > 0) {
            [event addAttribute:kNRMA_Attrib_contentType value:contentType];
        }
        
        if (requestData.trackedHeaders.count > 0) {
            for(NSString* key in requestData.trackedHeaders.allKeys) {
                [event addAttribute:key value:requestData.trackedHeaders[key]];
            }
        }
        
        return [_eventManager addEvent:[event autorelease]];
    } @catch (NSException *exception) {
        NRLOG_AGENT_ERROR(@"Failed to add Network Event.: %@", exception.reason);
    }
}

- (BOOL)addNetworkErrorEvent:(NRMANetworkRequestData *)requestData
                withResponse:(NRMANetworkResponseData *)responseData
                 withNRMAPayload:(NRMAPayload*)payload {
    if ([NRMAFlags shouldEnableRequestErrorEvents]) {
        NRMANetworkErrorEvent *event = (NRMANetworkErrorEvent*)[self createErrorEvent:requestData withResponse:responseData withNRMAPayload:payload];
        if(event == nil){ return NO; }
        [event addAttribute:kNRMA_Attrib_errorType value:kNRMA_Val_errorType_Network];
            
        return [_eventManager addEvent:[event autorelease]];
    }
    return NO;
}

- (BOOL) addHTTPErrorEvent:(NRMANetworkRequestData *)requestData
            withResponse:(NRMANetworkResponseData *)responseData
            withNRMAPayload:(NRMAPayload *)payload {
    if ([NRMAFlags shouldEnableRequestErrorEvents]) {
        NRMANetworkErrorEvent *event = (NRMANetworkErrorEvent*)[self createErrorEvent:requestData withResponse:responseData withNRMAPayload:payload];
        if(event == nil){ return NO; }
        [event addAttribute:kNRMA_Attrib_errorType value:kNRMA_Val_errorType_HTTP];

        return [_eventManager addEvent:[event autorelease]];
    }
    return NO;
}

- (id<NRMAAnalyticEventProtocol>)createErrorEvent:(NRMANetworkRequestData *)requestData
           withResponse:(NRMANetworkResponseData *)responseData
             withNRMAPayload:(NRMAPayload *)payload {
    @try {
        NSString* distributedTracingId = @"";
        NSString* traceId = @"";
        bool addDistributedTracing = false;
        if (payload != nil) {
            distributedTracingId = payload.id;
            traceId = payload.traceId;
            addDistributedTracing = payload.dtEnabled;
        }
        
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
        
        if (requestUrl.length == 0) {
            NRLOG_AGENT_WARNING(@"Unable to add NetworkEvent with empty URL.");
            return nil;
        }
        
        NRMANetworkErrorEvent *event = [[NRMANetworkErrorEvent alloc] initWithTimestamp:[NRMAAnalytics currentTimeMillis] sessionElapsedTimeInSeconds:sessionDuration_sec encodedResponseBody:encodedResponseBody appDataHeader:appDataHeader payload:payload withAttributeValidator:_attributeValidator];
        if (event == nil) {
            return nil;
        }
        
        [event addAttribute:kNRMA_Attrib_requestUrl value:requestUrl];
        [event addAttribute:kNRMA_Attrib_responseTime value:responseTime];
        
        if (addDistributedTracing) {
            if (distributedTracingId.length > 0) {
                [event addAttribute:kNRMA_Attrib_dtGuid value:distributedTracingId];
                [event addAttribute:kNRMA_Attrib_dtId value:distributedTracingId];
            }
            if (traceId.length > 0) {
                [event addAttribute:kNRMA_Attrib_dtTraceId value:traceId];
            }
        }
        
        if (requestDomain.length > 0) {
            [event addAttribute:kNRMA_Attrib_requestDomain value:requestDomain];
        }
        
        if (requestPath.length > 0) {
            [event addAttribute:kNRMA_Attrib_requestPath value:requestPath];
        }
        
        if (requestMethod.length > 0) {
            [event addAttribute:kNRMA_Attrib_requestMethod value:requestMethod];
        }
        
        if (connectionType.length > 0) {
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
        
        if (contentType.length > 0) {
            [event addAttribute:kNRMA_Attrib_contentType value:contentType];
        }
        
        if (requestData.trackedHeaders.count > 0) {
            for(NSString* key in requestData.trackedHeaders.allKeys) {
                [event addAttribute:key value:requestData.trackedHeaders[key]];
            }
        }
        
        return event;
    } @catch (NSException *exception) {
        NRLOG_AGENT_ERROR(@"Failed to add Network Event.: %@", exception.reason);
    }
}

- (BOOL)addNetworkRequestEvent:(NRMANetworkRequestData *)requestData
                  withResponse:(NRMANetworkResponseData *)responseData
                   withPayload:(std::unique_ptr<const Connectivity::Payload>)payload {
    if ([NRMAFlags shouldEnableNetworkRequestEvents]) {
        NewRelic::NetworkRequestData* networkRequestData = [requestData getNetworkRequestData];
        NewRelic::NetworkResponseData* networkResponseData = [responseData getNetworkResponseData];
        return _analyticsController->addRequestEvent(*networkRequestData, *networkResponseData, std::move(payload), [self checkOfflineStatus], [self checkBackgroundStatus]);
    }
    return NO;
}

- (BOOL)addNetworkErrorEvent:(NRMANetworkRequestData *)requestData
                withResponse:(NRMANetworkResponseData *)responseData
                 withPayload:(std::unique_ptr<const NewRelic::Connectivity::Payload>)payload {
    if ([NRMAFlags shouldEnableRequestErrorEvents]) {
        NewRelic::NetworkRequestData* networkRequestData = [requestData getNetworkRequestData];
        NewRelic::NetworkResponseData* networkResponseData = [responseData getNetworkResponseData];

        return _analyticsController->addNetworkErrorEvent(*networkRequestData, *networkResponseData,std::move(payload), [self checkOfflineStatus], [self checkBackgroundStatus]);
    }

    return NO;
}

- (BOOL)addHTTPErrorEvent:(NRMANetworkRequestData *)requestData
             withResponse:(NRMANetworkResponseData *)responseData
            withPayload:(std::unique_ptr<const NewRelic::Connectivity::Payload>)payload {
    if ([NRMAFlags shouldEnableRequestErrorEvents]) {
        NewRelic::NetworkRequestData* networkRequestData = [requestData getNetworkRequestData];
        NewRelic::NetworkResponseData* networkResponseData = [responseData getNetworkResponseData];

        return _analyticsController->addHTTPErrorEvent(*networkRequestData, *networkResponseData, std::move(payload), [self checkOfflineStatus], [self checkBackgroundStatus]);
    }
    return NO;
}

- (BOOL) setLastInteraction:(NSString*)name {
    if([NRMAFlags shouldEnableNewEventSystem]){
        return [_sessionAttributeManager setLastInteraction:name];
    } else {
        return [self setNRSessionAttribute:kNRMA_RA_lastInteraction
                                     value:name];
    }
}

- (BOOL) setNRSessionAttribute:(NSString*)name value:(id)value {
    if([NRMAFlags shouldEnableNewEventSystem]){
        return [_sessionAttributeManager setNRSessionAttribute:name value:value];
    } else {
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
                NRLOG_AGENT_VERBOSE(@"Session attribute \'value\' must be either an NSString* or NSNumber*");
                return NO;
            }
        } catch (std::exception& error) {
            NRLOG_AGENT_VERBOSE(@"failed to add NR session attribute, \'%@\' : %s",name, error.what());
            return NO;
        } catch (...) {
            NRLOG_AGENT_VERBOSE(@"failed to add NR session attribute.");
            return NO;
            
        }
    }
}

- (BOOL) setSessionAttribute:(NSString*)name value:(id)value persistent:(BOOL)isPersistent {
    if([NRMAFlags shouldEnableNewEventSystem]){
        // All values are persisted
        return [_sessionAttributeManager setSessionAttribute:name value:value];
    } else {
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
                NRLOG_AGENT_ERROR(@"Session attribute \'value\' must be either an NSString* or NSNumber*");
                return NO;
            }
        } catch (std::exception& error) {
            NRLOG_AGENT_ERROR(@"failed to add session attribute: \'%@\': %s",name ,error.what());
            return NO;
        } catch (...) {
            NRLOG_AGENT_ERROR(@"failed to add session attribute.");
            return NO;
            
        }
    }
}

- (BOOL) setSessionAttribute:(NSString*)name value:(id)value {
    if([NRMAFlags shouldEnableNewEventSystem]){
        return [_sessionAttributeManager setSessionAttribute:name value:value];
    } else {
        try {
            if ([value isKindOfClass:[NSNumber class]]) {
                NSNumber* number = (NSNumber*)value;
                if([NewRelicInternalUtils isInteger:number]) {
                    return _analyticsController->addSessionAttribute([name UTF8String], [number longLongValue]);
                }
                if([NewRelicInternalUtils isFloat:number]) {
                    return _analyticsController->addSessionAttribute([name UTF8String], [number doubleValue]);
                }
                if ([NewRelicInternalUtils isBool:number]) {
                    return _analyticsController->addSessionAttribute([name UTF8String], (bool)[number boolValue]);
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
                NRLOG_AGENT_ERROR(@"Session attribute \'value\' must be either an NSString* or NSNumber*");
                return NO;
            }
        } catch (std::exception& error) {
            NRLOG_AGENT_ERROR(@"failed to add session attribute: \'%@\': %s",name ,error.what());
            return NO;
        } catch (...) {
            NRLOG_AGENT_ERROR(@"failed to add session attribute.");
            return NO;
            
        }
    }
}

- (BOOL) setUserId:(NSString *)userId {
    if([NRMAFlags shouldEnableNewEventSystem]){
        return [_sessionAttributeManager setUserId:userId];
    } else {
        return [self setSessionAttribute:kNRMA_Attrib_userId
                                   value:userId
                              persistent:YES];
    }
}

- (BOOL) removeSessionAttributeNamed:(NSString*)name {
    if([NRMAFlags shouldEnableNewEventSystem]){
        return [_sessionAttributeManager removeSessionAttributeNamed:name];
    } else {
        try {
            return _analyticsController->removeSessionAttribute(name.UTF8String);
        } catch (std::exception& e) {
            NRLOG_AGENT_ERROR(@"Failed to remove attribute: %s",e.what());
            return NO;
        } catch (...) {
            NRLOG_AGENT_ERROR(@"Failed to remove attribute.");
            return NO;
        }
    }
}
- (BOOL) removeAllSessionAttributes {
    if([NRMAFlags shouldEnableNewEventSystem]){
        return [_sessionAttributeManager removeAllSessionAttributes];
    } else {
        try {
            return _analyticsController->clearSessionAttributes();
        } catch (std::exception& e) {
            NRLOG_AGENT_ERROR(@"Failed to remove all attributes: %s",e.what());
            return NO;
        } catch (...) {
            NRLOG_AGENT_ERROR(@"Failed to remove all attributes.");
            return NO;
            
        }
    }
}

- (BOOL) addEventNamed:(NSString*)name withAttributes:(NSDictionary*)attributes {
    if([NRMAFlags shouldEnableNewEventSystem]){
        if(name == nil || name.length == 0){return NO;}
        NRMACustomEvent *event = [[NRMACustomEvent alloc] initWithEventType:name
                                                                  timestamp:[NRMAAnalytics currentTimeMillis]
                                                sessionElapsedTimeInSeconds:[[NSDate date] timeIntervalSinceDate:_sessionStartTime]
                                                     withAttributeValidator:_attributeValidator];
        [attributes enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
            [event addAttribute:key value:obj];
        }];
        
        return [_eventManager addEvent:[event autorelease]];
    } else {
        try {
            auto event = _analyticsController->newEvent(name.UTF8String);
            if (event == nullptr) {
                NRLOG_AGENT_ERROR(@"Unable to create event with name: \"%@\"",name);
                return NO;
            }
            
            if ([self event:event withAttributes:attributes]) {
                if([self checkOfflineStatus]){
                    event->addAttribute(kNRMA_Attrib_offline.UTF8String, @YES.boolValue);
                }
                return _analyticsController->addEvent(event);
            }
        } catch (std::exception& e){
            NRLOG_AGENT_ERROR(@"Failed to add event: %s",e.what());
            return NO;
        } catch (...) {
            NRLOG_AGENT_ERROR(@"Failed to add event named: %@.\nPossible due to reserved word conflict.",name);
            return NO;
        }
        return NO;
    }
}

- (BOOL) addBreadcrumb:(NSString*)name
        withAttributes:(NSDictionary*)attributes {
    if([NRMAFlags shouldEnableNewEventSystem]){
        if(!name.length) {
            NRLOG_AGENT_ERROR(@"Breadcrumb must be named.");
            return NO;
        }
        NRMACustomEvent *event = [[NRMACustomEvent alloc] initWithEventType:kNRMA_RET_mobileBreadcrumb
                                                                  timestamp:[NRMAAnalytics currentTimeMillis]
                                                sessionElapsedTimeInSeconds:[[NSDate date] timeIntervalSinceDate:_sessionStartTime]
                                                     withAttributeValidator:_attributeValidator];
        if (event == nil) {
            NRLOG_AGENT_ERROR(@"Unable to create breadcrumb event");
            return NO;
        }
        
        [event addAttribute:kNRMA_Attrib_name value:name]; // Add the name as an attribute
        
        [attributes enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
            [event addAttribute:key value:obj];
        }];
        
        return [_eventManager addEvent:[event autorelease]];
    } else {
        try {
            
            if(!name.length) {
                NRLOG_AGENT_ERROR(@"Breadcrumb must be named.");
                return NO;
            }
            
            auto event = _analyticsController->newBreadcrumbEvent();
            if (event == nullptr) {
                NRLOG_AGENT_ERROR(@"Unable to create breadcrumb event");
                return NO;
            }
            
            if ([self event:event withAttributes:attributes]) {
                event->addAttribute("name",name.UTF8String);
                if([self checkOfflineStatus]){
                    event->addAttribute(kNRMA_Attrib_offline.UTF8String, @YES.boolValue);
                }
                return _analyticsController->addEvent(event);
            }
        } catch (std::exception& e){
            NRLOG_AGENT_ERROR(@"Failed to add event: %s",e.what());
            return NO;
        } catch (...) {
            NRLOG_AGENT_ERROR(@"Failed to add event named: %@.\nPossible due to reserved word conflict.",name);
            return NO;
        }
        return NO;
    }
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
                NRLOG_AGENT_ERROR(@"addCustomEvent failed with error: %@",error);
                return false;
            }
        }

        NSArray* textCheckingResults = [__eventTypeRegex matchesInString:eventType
                                                                 options:NSMatchingReportCompletion
                                                                   range:NSMakeRange(0, eventType.length)];

        if (!(textCheckingResults.count > 0 && ((NSTextCheckingResult*)textCheckingResults[0]).range.length == eventType.length)) {
            NRLOG_AGENT_ERROR(@"Failed to add event type: %@. EventType is may only contain word characters, numbers, spaces, colons, underscores, and periods.",eventType);
            return NO;
        }

        if([NRMAFlags shouldEnableNewEventSystem]){
            NRMACustomEvent* event = [[NRMACustomEvent alloc] initWithEventType:eventType
                                                                      timestamp:[NRMAAnalytics currentTimeMillis]
                                                    sessionElapsedTimeInSeconds:[[NSDate date] timeIntervalSinceDate:_sessionStartTime] withAttributeValidator:_attributeValidator];
            [attributes enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
                [event addAttribute:key value:obj];
            }];
            [_eventManager addEvent:[event autorelease]];
            
            return YES;
        } else {
            auto event = _analyticsController->newCustomEvent(eventType.UTF8String);
            
            if (event == nullptr) {
                NRLOG_AGENT_ERROR(@"Unable to create event with name: \"%@\"",eventType);
                return NO;
            }
                        
            if([self event:event withAttributes:attributes]) {
                if([self checkOfflineStatus]){
                    event->addAttribute(kNRMA_Attrib_offline.UTF8String, @YES.boolValue);
                }
                return _analyticsController->addEvent(event);
            }
        }
    } catch (std::exception& e){
        NRLOG_AGENT_ERROR(@"Failed to add event: %s",e.what());
        return NO;
    } catch (...) {
        NRLOG_AGENT_ERROR(@"Failed to add event named: %@.\nPossible due to reserved word conflict.",eventType);
        return NO;
    }
    return NO;
}

- (BOOL) event:(std::shared_ptr<AnalyticEvent>)event withAttributes:(NSDictionary*)attributes {
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
                NRLOG_AGENT_ERROR(@"Failed to add attribute \"%@\" value is invalid NSNumber with objCType: %s",key,[number objCType]);
            }
        } else if([value isKindOfClass:[NRMABool class]]) {
            event->addAttribute(key.UTF8String, (bool)((NRMABool*)value).value);
        } else {
            NRLOG_AGENT_ERROR(@"Failed to add attribute values must be type NSNumber* or NSString*.");
        }
    }
    return YES;
}

- (BOOL) checkOfflineStatus {
    if([NRMAFlags shouldEnableOfflineStorage]) {
        NRMAReachability* r = [NewRelicInternalUtils reachability];
        @synchronized(r) {
#if TARGET_OS_WATCH
            NRMANetworkStatus status = [NewRelicInternalUtils currentReachabilityStatusTo:[NSURL URLWithString:[NewRelicInternalUtils collectorHostDataURL]]];
#else
            NRMANetworkStatus status = [r currentReachabilityStatus];
#endif
            return (status == NotReachable);
        }
    }
    return false;
}

- (BOOL) checkBackgroundStatus {
    if([NRMAFlags shouldEnableBackgroundReporting]) {
#if TARGET_OS_WATCH
        return ([NewRelicAgentInternal sharedInstance].currentApplicationState == WKApplicationStateBackground);
#else
        return ([NewRelicAgentInternal sharedInstance].currentApplicationState == UIApplicationStateBackground);
#endif
    }
    return false;
}

- (BOOL)recordUserAction:(NRMAUserAction *)userAction {
    if (userAction == nil) { return NO; };
    
    NRMACustomEvent* event = [[NRMACustomEvent alloc] initWithEventType:kNRMA_RET_mobileUserAction
                                                              timestamp:[NRMAAnalytics currentTimeMillis]
                                            sessionElapsedTimeInSeconds:[[NSDate date] timeIntervalSinceDate:_sessionStartTime] withAttributeValidator:_attributeValidator];

    if (userAction.associatedMethod.length > 0) {
        [event addAttribute:kNRMA_RA_methodExecuted value:userAction.associatedMethod];
    }

    if (userAction.associatedClass.length > 0) {
        [event addAttribute:kNRMA_RA_targetObject value:userAction.associatedClass];
    }

    if (userAction.elementLabel.length > 0) {
        [event addAttribute:kNRMA_RA_label value:userAction.elementLabel];
    }

    if ((userAction.accessibilityId.length > 0)) {
        [event addAttribute:kNRMA_RA_accessibility value:userAction.accessibilityId];
    }

    if ((userAction.interactionCoordinates.length > 0)) {
        [event addAttribute:kNRMA_RA_touchCoordinates value:userAction.interactionCoordinates];
    }

    if ((userAction.actionType.length > 0)) {
        [event addAttribute:kNMRA_RA_actionType value:userAction.actionType];
    }

    if ((userAction.elementFrame.length > 0)) {
        [event addAttribute:kNRMA_RA_frame value:userAction.elementFrame];
    }

    NSString* deviceOrientation = [NewRelicInternalUtils deviceOrientation];
    if (deviceOrientation.length > 0) {
        [event addAttribute:kNRMA_RA_orientation value:deviceOrientation];
    }

    return [_eventManager addEvent:[event autorelease]];
}

- (BOOL) incrementSessionAttribute:(NSString*)name value:(NSNumber*)number
{
    if([NRMAFlags shouldEnableNewEventSystem]){
        return [_sessionAttributeManager incrementSessionAttribute:name value:number];
    } else {
        if ([NewRelicInternalUtils isInteger:number]) {
            return _analyticsController->incrementSessionAttribute([name UTF8String], (unsigned long long)[number longLongValue]); //has internal exception handling
        } else if ([NewRelicInternalUtils isFloat:number]) {
            return _analyticsController->incrementSessionAttribute([name UTF8String], [number doubleValue]); //has internal exception handling
        } else {
            return NO;
        }
    }
}

- (BOOL) incrementSessionAttribute:(NSString*)name value:(NSNumber*)number persistent:(BOOL)persistent {
    if([NRMAFlags shouldEnableNewEventSystem]){
        return [_sessionAttributeManager incrementSessionAttribute:name value:number];
    } else {
        if ([NewRelicInternalUtils isInteger:number]) {
            return _analyticsController->incrementSessionAttribute([name UTF8String], (unsigned long long)[number longLongValue],(bool)persistent); //has internal exception handling.
        } else if ([NewRelicInternalUtils isFloat:number]) {
            return _analyticsController->incrementSessionAttribute([name UTF8String], [number doubleValue],(bool)persistent); //has internal exception handling.
        } else {
            return NO;
        }
    }
}

- (NSString*) analyticsJSONString {
    if([NRMAFlags shouldEnableNewEventSystem]){
        NSError *error = nil;
        return [_eventManager getEventJSONStringWithError:&error clearEvents:true];
    } else {
        try {
            auto events = _analyticsController->getEventsJSON(true);
            std::stringstream stream;
            stream <<std::setprecision(13)<< *events;
            return [NSString stringWithUTF8String:stream.str().c_str()];
        } catch (std::exception& e) {
            NRLOG_AGENT_VERBOSE(@"Failed to generate event json: %s",e.what());
        } catch (...) {
            NRLOG_AGENT_VERBOSE(@"Failed to generate event json");
        }
        return nil;
    }
}

- (NSString*) sessionAttributeJSONString {
    if([NRMAFlags shouldEnableNewEventSystem]){
        return [_sessionAttributeManager sessionAttributeJSONString];
    } else {
        try {
            auto attributes = _analyticsController->getSessionAttributeJSON();
            std::stringstream stream;
            stream <<std::setprecision(13)<<*attributes;
            return [NSString stringWithUTF8String:stream.str().c_str()];
        } catch (std::exception& e) {
            NRLOG_AGENT_VERBOSE(@"Failed to generate attributes json: %s",e.what());
        } catch (...) {
            NRLOG_AGENT_VERBOSE(@ "Failed to generate attributes json.");
        }
        return nil;
    }
}
+ (NSString*) getLastSessionsAttributes {
    if([NRMAFlags shouldEnableNewEventSystem]){
        return [NRMASAM getLastSessionsAttributes];
    } else {
        
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
            NRLOG_AGENT_VERBOSE(@"failed to generate session attribute json: %s", e.what());
        } catch (...) {
            NRLOG_AGENT_VERBOSE(@"failed to generate session attribute json.");
        }
        return nil;
    }
}

+ (NSString*) getLastSessionsEvents{
    if([NRMAFlags shouldEnableNewEventSystem]) {
        NSString *filename = [[NewRelicInternalUtils getStorePath] stringByAppendingPathComponent:kNRMA_EventStoreFilename];
        return [NRMAEventManager getLastSessionEventsFromFilename:filename];
    } else {
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
            NRLOG_AGENT_VERBOSE(@"Failed to fetch event dup store: %s",e.what());
            
        } catch (...) {
            NRLOG_AGENT_VERBOSE(@"Failed to fetch event dup store.");
        }
    }
    
    return nil;
}

+ (void) clearDuplicationStores
{
    try {
        [self attributeDupStore].clear();
        [self eventDupStore].clear();
    } catch (std::exception& e) {
        NRLOG_AGENT_VERBOSE(@"Failed to clear dup stores: %s",e.what());
    } catch(...) {
        NRLOG_AGENT_VERBOSE(@"Failed to clear dup stores.");
    }
}


- (void) clearLastSessionsAnalytics {
    if([NRMAFlags shouldEnableNewEventSystem]){
        [_sessionAttributeManager removeAllSessionAttributes];
        [_eventManager empty];
    } else {
        try {
            _analyticsController->clearAttributesDuplicationStore();
            _analyticsController->clearEventsDuplicationStore();
        } catch (std::exception& e) {
            NRLOG_AGENT_VERBOSE(@"Failed to clear last sessions' analytcs, %s",e.what());
        } catch (...) {
            NRLOG_AGENT_VERBOSE(@"Failed to clear last sessions' analytcs.");
        }
    }
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

    [self endSessionReusable];
}

- (void) newSession {
    _newSession = YES;
    [self endSessionReusable];
}

- (void) newSessionWithStartTime:(long long)sessionStartTime {
    [self setSessionStartTime:sessionStartTime];
    if(!([NRMAFlags shouldEnableNewEventSystem])) {
        _analyticsController->newSessionWithStartTime(sessionStartTime);
    }
    [self newSession];
}

- (void) endSessionReusable {
    if([NRMAFlags shouldEnableNewEventSystem]){
        if(![self addSessionEndAttribute]) { //has exception handling within
            NRLOG_AGENT_ERROR(@"failed to add session end attribute.");
        }

        if(![self addSessionEvent]) { //has exception handling within
            NRLOG_AGENT_ERROR(@"failed to add a session event");
        }
    }
    else {
        if(!_analyticsController->addSessionEndAttribute()) { //has exception handling within
            NRLOG_AGENT_ERROR(@"failed to add session end attribute.");
        }

        if(!_analyticsController->addSessionEvent()) { //has exception handling within
            NRLOG_AGENT_ERROR(@"failed to add a session event");
        }
    }
}

- (void) onHarvestBefore {
    if([NRMAFlags shouldEnableNewEventSystem]){
        if (_sessionWillEnd || _newSession || [_eventManager didReachMaxQueueTime: [NRMAAnalytics currentTimeMillis]]) {
            _newSession = NO;
            [self handleHarvest];
        }
    }
    else {
        if (_sessionWillEnd || _newSession || _analyticsController->didReachMaxEventBufferTime()) {
            _newSession = NO;
            [self handleHarvest];
        }
    }
}

-(void) handleHarvest {
    NRMAHarvestableAnalytics* harvestableAnalytics = [[NRMAHarvestableAnalytics alloc] initWithAttributeJSON:[self sessionAttributeJSONString]
                                                                                                    EventJSON:[self analyticsJSONString]];

    [NRMAHarvestController addHarvestableAnalytics:harvestableAnalytics];
    [harvestableAnalytics release];
}

- (BOOL) addSessionEndAttribute {

    NSTimeInterval elapsed = [[NSDate date] timeIntervalSinceDate:_sessionStartTime];

    if (![_sessionAttributeManager setNRSessionAttribute:kNRMA_RA_sessionDuration value:@(elapsed)]) {
        NRLOG_AGENT_ERROR(@"failed to add session end attribute.");
        return NO;
    }

    return YES;
}

- (BOOL) addSessionEvent {
    NRMASessionEvent *event = [[NRMASessionEvent alloc] initWithTimestamp:[NRMAAnalytics currentTimeMillis]
                                              sessionElapsedTimeInSeconds:[[NSDate date] timeIntervalSinceDate:_sessionStartTime]
                                                                 category:@"Session" withAttributeValidator:_attributeValidator];

    return [_eventManager addEvent:[event autorelease]];
}

- (id<AttributeValidatorProtocol>) getAttributeValidator {
    return _attributeValidator;
}

#pragma mark Static helpers.

+ (int64_t) currentTimeMillis {
    double timestamp = [[NSDate date] timeIntervalSince1970];
    int64_t timeInMilisInt64 = (int64_t)(timestamp * 1000);
    return timeInMilisInt64;
}

+ (NSArray<NSString*>*) reservedKeywords {
    return [NSArray arrayWithObjects:
            kNRMA_RA_eventType,
            kNRMA_RA_type,
            kNRMA_RA_timestamp,
            kNRMA_RA_category,
            kNRMA_RA_accountId,
            kNRMA_RA_appId,
            kNRMA_RA_appName,
            kNRMA_RA_uuid,
            kNRMA_RA_sessionDuration,
            kNRMA_RA_osName,
            kNRMA_RA_osVersion,
            kNRMA_RA_osMajorVersion,
            kNRMA_RA_deviceManufacturer,
            kNRMA_RA_deviceModel,
            kNRMA_RA_carrier,
            kNRMA_RA_newRelicVersion,
            kNRMA_RA_memUsageMb,
            kNRMA_RA_sessionId,
            kNRMA_RA_install,
            kNRMA_RA_upgradeFrom,
            kNRMA_RA_platform,
            kNRMA_RA_platformVersion,
            kNRMA_RA_lastInteraction
        ,nil];
}

@end
