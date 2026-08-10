 //
//  NRMAHandledExceptions.m
//  NewRelicAgent
//
//  Created by Bryce Buchanan on 6/26/17.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import "NRMAHandledExceptions.h"

#include <exception>
#include <Hex/HexController.hpp>
#include <Hex/HexPersistenceManager.hpp>
#import "NewRelicInternalUtils.h"
#import "NRMAExceptionReportAdaptor.h"
#import "NRLogger.h"
#import "HexUploadPublisher.hpp"
#import "NRMAHarvestController.h"
#import "NRMAAppToken.h"
#include <execinfo.h>
#import "NRMAFlags.h"
#include <Analytics/AnalyticsController.hpp>
#import "NRMABool.h"
#import "NRMASupportMetricHelper.h"
#import "Constants.h"
#import "NRMAAttributeValidator.h"

// Session Replay Error Sampling
// END

@interface NRMAAnalytics(Protected)
// Because the NRMAAnalytics class interfaces with non Objective-C++ files, we cannot expose the API on the header. Therefore, we must use this reference.
- (std::shared_ptr<NewRelic::AnalyticsController>&) analyticsController;
@end

// The public record* entry points are thin wrappers that validate their input
// and then call these. The split exists so the C++ catch-all in the wrapper
// covers the whole body without re-indenting it.
@interface NRMAHandledExceptions (Guarded)
- (void) recordErrorInternal:(NSError*)error attributes:(NSDictionary*)attributes;
- (void) recordHandledExceptionInternal:(NSException*)exception attributes:(NSDictionary*)attributes;
- (void) recordHandledExceptionWithStackTraceInternal:(NSDictionary*)exceptionDictionary;
@end

// Runs `body`, absorbing any C++ exception it throws. ObjC exceptions are
// re-thrown unchanged — see the catch(id) handler for why.
//
// libMobileAgent is built with C++ exceptions enabled, and the report path can
// throw: HexReport::finalize raises std::invalid_argument for a report missing
// its exception or app info, and every vector/shared_ptr allocation along the
// way can raise std::bad_alloc under memory pressure. Without this barrier such
// an exception unwinds out of the ObjC frame into the caller — and callers are
// usually Swift (NewRelicClient.recordException and friends). A C++ exception
// crossing a Swift frame is an unconditional std::terminate, so one
// unserializable report would abort the host app. Dropping the report is
// always the better outcome.
static void NRMAGuardCxx(NSString* context, void (^body)(void)) {
    try {
        body();
    } catch (id) {
        // Deliberately NOT absorbed. Under the unified 64-bit exception model an
        // @throw'n ObjC object is itself a C++ exception, so the bare catch(...)
        // below would swallow NSExceptions too. Raising NSInvalidArgumentException
        // for a malformed argument — e.g. an NSError whose localizedDescription is
        // an NSNull, so -UTF8String is an unrecognized selector — is long-standing,
        // tested behavior that surfaces a caller programming error. Hiding it would
        // turn a loud bug into a silently dropped report.
        throw;
    } catch (const std::exception& e) {
        NRLOG_AGENT_ERROR(@"%@ failed: %s", context, e.what());
    } catch (...) {
        NRLOG_AGENT_ERROR(@"%@ failed: unknown C++ exception", context);
    }
}

const NSString* kHexBackupStoreFolder = @"hexbkup/";

@implementation NRMAHandledExceptions {
    NewRelic::Hex::HexController* _controller;
    std::shared_ptr<NewRelic::AnalyticsController> _analytics;
    std::shared_ptr<NewRelic::Hex::HexPersistenceManager> _persistenceManager;
    std::shared_ptr<NewRelic::Hex::HexStore> _store;
    NewRelic::Hex::Report::ApplicationLicense* _appLicense;
    NewRelic::Hex::HexUploadPublisher* _publisher;

    NRMAAnalytics *analyticsParent;
    id<AttributeValidatorProtocol> _attributeValidator;

    // Single-flight guard for processAndPublishPersistedReports. Without it,
    // every harvest tick that sees the network reachable can spawn a fresh
    // backlog flush even while the previous one is still draining — under
    // low-bandwidth that races and creates duplicate uploads + FD pressure.
    BOOL _persistFlushInFlight;
}

- (void) dealloc {

    delete _controller;
    delete _appLicense;
    delete _publisher;

    self.sessionId = nil;
    self.sessionStartDate = nil;
    [_attributeValidator release];

    [super dealloc];
}

- (instancetype) initWithAnalyticsController:(NRMAAnalytics*)analytics
                            sessionStartTime:(NSDate*)sessionStartDate
                          agentConfiguration:(NRMAAgentConfiguration*)agentConfiguration
                                    platform:(NSString*)platform
                                   sessionId:(NSString*)sessionId
                                attributeValidator:(id<AttributeValidatorProtocol>) attributeValidator {
    if (analytics == nil || sessionStartDate == nil || [agentConfiguration applicationToken] == nil || platform == nil || sessionId == nil) {
        NSMutableArray* missingParams = [[NSMutableArray new] autorelease];
        if ([agentConfiguration applicationToken] == nil) [missingParams addObject:@"appToken"];
        if (platform == nil) [missingParams addObject:@"platformName"];
        if (sessionId == nil) [missingParams addObject:@"sessionId"];
        if (analytics == nil) [missingParams addObject:@"AnalyticsController"];
        if (sessionStartDate == nil) [missingParams addObject:@"SessionStartDate"];
        NRLOG_AGENT_ERROR(@"Failed to create handled exception object. Key parameter(s) are nil: %@. This will prevent handle exception reporting.",  [missingParams componentsJoinedByString:@", "]);
        return nil;
    }
    self = [super init];
    if (self) {
        analyticsParent = analytics;
        
        _attributeValidator = [attributeValidator retain];

        _analytics = std::shared_ptr<NewRelic::AnalyticsController>([analytics analyticsController]);
        self.sessionStartDate = sessionStartDate;
        std::vector<std::shared_ptr<NewRelic::Hex::Report::Library>> libs;
        NSString* appToken = agentConfiguration.applicationToken.value;
        NSString* protocol = agentConfiguration.useSSL?@"https://":@"http://";
        NSString* collectorHost = [NSString stringWithFormat:@"%@%@%@",
                                                             protocol,
                                                             agentConfiguration.collectorHost,
                                                             kNRMA_Collector_hex_url];

        NSString* version = [NRMAAgentConfiguration connectionInformation].applicationInformation.appVersion;

        if (appToken == nil || appToken.length == 0) {
            NRLOG_AGENT_ERROR(@"Failed to create Handled Exception Manager: missing application token.");
            return nil;
        }

        if (version == nil || version.length == 0) {
            NRLOG_AGENT_ERROR(@"Failed to create Handled Exception Manager: no version number.");
            return nil;
        }

        if (collectorHost == nil || collectorHost.length == 0) {
            NRLOG_AGENT_ERROR(@"Failed to create Handled Exception Manager: no host specified.");
            return nil;
        }

        if (sessionId == nil || sessionId.length == 0) {
            NRLOG_AGENT_ERROR(@"Failed to create Handled Exception Manager: session id not specified.");
            return nil;
        }

        self.sessionId = sessionId;

        _appLicense = new NewRelic::Hex::Report::ApplicationLicense(appToken.UTF8String);


        _publisher = new NewRelic::Hex::HexUploadPublisher([NewRelicInternalUtils getStorePath].UTF8String,
                                                                        appToken.UTF8String,
                                                                        version.UTF8String,
                                                                        collectorHost.UTF8String);

        NSString* backupStorePath = [NSString stringWithFormat:@"%@/%@",[NewRelicInternalUtils getStorePath],kHexBackupStoreFolder];
        NSError* error = nil;

        [[NSFileManager defaultManager] createDirectoryAtPath:backupStorePath
                                  withIntermediateDirectories:YES
                                                   attributes:nil
                                                        error:&error];
        if (error) {
            NRLOG_AGENT_ERROR(@"NEWRELIC SETUP - Failed to create handled exceptions directory: %@",error);
        }

        _store = std::make_shared<NewRelic::Hex::HexStore>(backupStorePath.UTF8String);

        _persistenceManager = std::make_shared<NewRelic::Hex::HexPersistenceManager>(_store,_publisher);

        _controller = new NewRelic::Hex::HexController(std::shared_ptr<const NewRelic::AnalyticsController>(_analytics), std::make_shared<NewRelic::Hex::Report::AppInfo>(_appLicense, [self fbsPlatformFromString:platform]), _publisher, _store, sessionId.UTF8String);
    }
    return self;
}

- (void) onHarvest {
    // Always upload handled exceptions from the on-disk store. Reports are persisted
    // by HexController::submit on the record path, and the persisted-report flush
    // deletes each report only once its upload is confirmed (see
    // HexStore::markUploaded). This keeps unconfirmed reports on disk across
    // launches / termination, and does not depend on the offline-storage flag —
    // a report is never destroyed before we know it was uploaded.
    NRMAReachability* r = [NewRelicInternalUtils reachability];
    @synchronized(r) {
#if TARGET_OS_WATCH
        NRMANetworkStatus status = [NewRelicInternalUtils currentReachabilityStatusTo:[NSURL URLWithString:[NewRelicInternalUtils collectorHostHexURL]]];
#else
        NRMANetworkStatus status = [r currentReachabilityStatus];
#endif
        if (status != NotReachable) {
            [self processAndPublishPersistedReports];
            // The in-memory keyContext is only a transient mirror of what submit()
            // already persisted to disk; reset it so reports are uploaded from disk
            // (the source of truth) without double-sending.
            _controller->resetKeyContext();
            _publisher->retry();
        }
    }
}

- (fbs::Platform) fbsPlatformFromString:(NSString*)platform {
    if ([platform isEqualToString:NRMA_OSNAME_TVOS]) {
        return fbs::Platform_tvOS;
    }
    else if ([platform isEqualToString:NRMA_OSNAME_WATCHOS]) {
        return fbs::Platform_watchOS;
    }
    return fbs::Platform_iOS;
}

- (void) checkOffline:(std::shared_ptr<NewRelic::Hex::Report::HexReport>) report
{
    if([NRMAFlags shouldEnableOfflineStorage]) {
        NRMAReachability* r = [NewRelicInternalUtils reachability];
        @synchronized(r) {
#if TARGET_OS_WATCH
            NRMANetworkStatus status = [NewRelicInternalUtils currentReachabilityStatusTo:[NSURL URLWithString:[NewRelicInternalUtils collectorHostHexURL]]];
#else
            NRMANetworkStatus status = [r currentReachabilityStatus];
#endif
            if (status == NotReachable) {
                report->setAttributeNoValidation(__kNRMA_Attrib_offline, true);
            }
        }
    }
}

- (void) recordError:(NSError * _Nonnull)error
          attributes:(NSDictionary* _Nullable)attributes
{
    // _Nonnull is a compile-time hint, not a runtime contract, and it is not
    // enforced at all across a Swift bridge or a dynamic-language bridge
    // (React Native / Cordova / Unity). A nil error here used to reach
    // HandledException's constructor as two null const char*s — a SIGSEGV in
    // std::string, not a catchable exception.
    if (error == nil) {
        NRLOG_AGENT_ERROR(@"Ignoring nil error.");
        return;
    }

    NRMAGuardCxx(@"recordError:attributes:", ^{
        [self recordErrorInternal:error attributes:attributes];
    });
}

- (void) recordErrorInternal:(NSError*)error
                  attributes:(NSDictionary*)attributes
{
    void* callstack[1024];
    int frames = backtrace(callstack,1024);

    // An NSError can legitimately have a nil localizedDescription, and a
    // subclass can return nil from -domain. Fall back to empty strings so
    // -UTF8String can never hand a null pointer to the C++ layer.
    NSString* eMessage = error.localizedDescription ?: @"";
    NSString* eDomain = error.domain ?: @"";

    if([NRMAFlags shouldEnableNewEventSystem]){
        auto resultMap = [self getSessionAttributesResultMap];

        auto report = _controller->createReport(uint64_t([[[NSDate new] autorelease] timeIntervalSince1970] * 1000),
                                                eMessage.UTF8String,
                                                eDomain.UTF8String,
                                                resultMap,
                                                [self createThreadVector:callstack length:frames]
                                                );
        
        NRMAExceptionReportAdaptor* contextAdapter = [[[NRMAExceptionReportAdaptor alloc] initWithReport:report attributeValidator:_attributeValidator] autorelease];

        if (attributes != nil) {
            [contextAdapter addAttributesNewValidation:attributes];
        }

        report->setAttributeNoValidation("timeSinceLoad", [[[NSDate new] autorelease] timeIntervalSinceDate:self.sessionStartDate]);

        report->setAttributeNoValidation("isHandledError", true);
        [self checkOffline:report];
        
        _controller->submit(report);
    }
    else {
        auto report = _controller->createReport(uint64_t([[[NSDate new] autorelease] timeIntervalSince1970] * 1000),
                                                eMessage.UTF8String,
                                                eDomain.UTF8String,
                                                [self createThreadVector:callstack length:frames]
                                                );
        
        NRMAExceptionReportAdaptor* contextAdapter = [[[NRMAExceptionReportAdaptor alloc] initWithReport:report attributeValidator:_attributeValidator] autorelease];

        if (attributes != nil) {
            [contextAdapter addAttributes:attributes];
        }
        
        report->setAttribute("timeSinceLoad", [[[NSDate new] autorelease] timeIntervalSinceDate:self.sessionStartDate]);
        
        report->setAttribute("isHandledError", true);
        
        [self checkOffline:report];

        _controller->submit(report);
    }
}

- (void) recordHandledException:(NSException*)exception
                     attributes:(NSDictionary*)attributes {
    if (exception == nil) {
        NRLOG_AGENT_ERROR(@"Ignoring nil exception.");
        return;
    }

    if (!exception.callStackReturnAddresses.count) {
        NSString* name = exception.name ?: NSStringFromClass([exception class]);
        NRLOG_AGENT_ERROR(@"Invalid exception. \"%@\" was recorded without being thrown. +[NewRelic %@] is reserved for thrown exceptions only.", name, NSStringFromSelector(_cmd));
        return;
    }

    NRMAGuardCxx(@"recordHandledException:attributes:", ^{
        [self recordHandledExceptionInternal:exception attributes:attributes];
    });
}

- (void) recordHandledExceptionInternal:(NSException*)exception
                             attributes:(NSDictionary*)attributes {
    NSString* eName = exception.name;
    if(!eName) {
        eName = NSStringFromClass([exception class]);
    }

    NSString* eReason = @"";
    if(exception.reason) {
        eReason = exception.reason;
    }
    if([NRMAFlags shouldEnableNewEventSystem]){
        auto resultMap = [self getSessionAttributesResultMap];
        auto report = _controller->createReport(uint64_t([[[NSDate new] autorelease] timeIntervalSince1970] * 1000),
                                                eReason.UTF8String,
                                                eName.UTF8String,
                                                resultMap,
                                                [self createThreadVector:exception]
                                                );
        report->setAttributeNoValidation("timeSinceLoad", [[[NSDate new] autorelease] timeIntervalSinceDate:self.sessionStartDate]);
        
        [self checkOffline:report];

        NRMAExceptionReportAdaptor* contextAdapter = [[[NRMAExceptionReportAdaptor alloc] initWithReport:report attributeValidator:_attributeValidator] autorelease];

        if (attributes != nil) {
            [contextAdapter addAttributesNewValidation:attributes];
        }

        _controller->submit(report);
    }
    else {
        auto report = _controller->createReport(uint64_t([[[NSDate new] autorelease] timeIntervalSince1970] * 1000),
                                                eReason.UTF8String,
                                                eName.UTF8String,
                                                [self createThreadVector:exception]);


        report->setAttribute("timeSinceLoad", [[[NSDate new] autorelease] timeIntervalSinceDate:self.sessionStartDate]);
        
        [self checkOffline:report];

        NRMAExceptionReportAdaptor* contextAdapter = [[[NRMAExceptionReportAdaptor alloc] initWithReport:report attributeValidator:_attributeValidator] autorelease];

        if (attributes != nil) {
            [contextAdapter addAttributes:attributes];
        }

        _controller->submit(report);
    }
}

- (void) recordHandledException:(NSException*)exception {
    [self recordHandledException:exception
                      attributes:nil];
}

- (std::vector<std::shared_ptr<NewRelic::Hex::Report::Thread>>) createThreadVector:(void**)stack length:(int)length {
    std::vector<std::shared_ptr<NewRelic::Hex::Report::Thread>> threadVector;
    std::vector<NewRelic::Hex::Report::Frame> frameVector;

    for(int i = 2; i < length; i++) {
        frameVector.push_back(NewRelic::Hex::Report::Frame(" ", (uint64_t)stack[i]));
    }
    threadVector.push_back(std::make_shared<NewRelic::Hex::Report::Thread>(frameVector));
    return threadVector;
}

- (std::vector<std::shared_ptr<NewRelic::Hex::Report::Thread>>) createThreadVector:(NSException*)exception {
    std::vector<std::shared_ptr<NewRelic::Hex::Report::Thread>> threadVector;
    std::vector<NewRelic::Hex::Report::Frame> frameVector;

    // We want to use callStackReturnAddresses rather than callStackSymbols It is a much less expensive call, and symbols will not be available On symbol-stripped binaries, anyway.
    for (NSNumber* frame in exception.callStackReturnAddresses) {
        frameVector.push_back(NewRelic::Hex::Report::Frame(" ", [frame unsignedLongLongValue]));
    }
    threadVector.push_back(std::make_shared<NewRelic::Hex::Report::Thread>(frameVector));
    return threadVector;
}

- (void) processAndPublishPersistedReports {
    @synchronized(self) {
        if (_persistFlushInFlight) return;
        _persistFlushInFlight = YES;
    }
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        @try {
            // @catch below only sees ObjC exceptions. retrieveAndPublishReports
            // reads and deserializes flatbuffers off disk, so it can also raise a
            // C++ exception — and a C++ exception escaping a dispatch block is an
            // unconditional std::terminate, with no @catch anywhere above it.
            NRMAGuardCxx(@"persisted-report flush", ^{
                _persistenceManager->retrieveAndPublishReports();
            });
        }
        @catch (NSException* ex) {
            NRLOG_AGENT_ERROR(@"persisted-report flush threw: %@", ex);
        }
        @finally {
            @synchronized(self) {
                _persistFlushInFlight = NO;
            }
        }
    });
}

- (void) recordHandledExceptionWithStackTrace:(NSDictionary*)exceptionDictionary {
    if (exceptionDictionary == nil) {
        NRLOG_AGENT_ERROR(@"Ignoring nil exception dictionary.");
        return;
    }

    NRMAGuardCxx(@"recordHandledExceptionWithStackTrace:", ^{
        [self recordHandledExceptionWithStackTraceInternal:exceptionDictionary];
    });
}

- (void) recordHandledExceptionWithStackTraceInternal:(NSDictionary*)exceptionDictionary {

    // This is the entry point used by the cross-platform bridges (React
    // Native, Cordova, Unity, Flutter), so the dictionary contents are wholly
    // caller-controlled — a bridge that omits "name" or "reason" produced a
    // nil NSString whose -UTF8String is null, and std::string(nullptr) is a
    // SIGSEGV rather than a catchable exception. The frame sub-dictionaries
    // below were already defended this way; the name and reason were not.
    NSString* eName = exceptionDictionary[@"name"] ?: @"";
    NSString* eReason = exceptionDictionary[@"reason"] ?: @"";
    NSMutableArray* stackTraceElements = exceptionDictionary[@"stackTraceElements"];

    // Begin: Assemble threadVector from the stackTraceElements dict.
    std::vector<std::shared_ptr<NewRelic::Hex::Report::Thread>> threadVector;
    std::vector<NewRelic::Hex::Report::Frame> frameVector;

    for (NSDictionary* frameDict in stackTraceElements) {
        NSString* className = frameDict[@"class"];
        if (!className) className = @" ";
        NSString* methodName = frameDict[@"method"];
        if (!methodName) methodName = @" ";
        NSString* fileName = frameDict[@"file"];
        if (!fileName) fileName = @" ";

        NSString* lineNumber = frameDict[@"line"];
        if (!lineNumber) lineNumber = @"1";
        frameVector.push_back(NewRelic::Hex::Report::Frame(className.UTF8String, methodName.UTF8String, fileName.UTF8String, (int64_t) [lineNumber intValue]));
    }

    threadVector.push_back(std::make_shared<NewRelic::Hex::Report::Thread>(frameVector));
    // END: Assemble threadVector from the stackTraceElements dict.


    if([NRMAFlags shouldEnableNewEventSystem]){
        auto resultMap = [self getSessionAttributesResultMap];
        auto report = _controller->createReport(uint64_t([[[NSDate new] autorelease] timeIntervalSince1970] * 1000),
                                                eReason.UTF8String,
                                                eName.UTF8String,
                                                resultMap,
                                                threadVector);
        report->setAttributeNoValidation("timeSinceLoad", [[[NSDate new] autorelease] timeIntervalSinceDate:self.sessionStartDate]);
        [self checkOffline:report];

        NRMAExceptionReportAdaptor* contextAdapter = [[[NRMAExceptionReportAdaptor alloc] initWithReport:report attributeValidator:_attributeValidator] autorelease];

        if (exceptionDictionary != nil) {
            [contextAdapter addAttributesNewValidation:exceptionDictionary];
        }

        _controller->submit(report);
    }
    else {
        auto report = _controller->createReport(uint64_t([[[NSDate new] autorelease] timeIntervalSince1970] * 1000),
                                                eReason.UTF8String,
                                                eName.UTF8String,
                                                threadVector);

        report->setAttribute("timeSinceLoad", [[[NSDate new] autorelease] timeIntervalSinceDate:self.sessionStartDate]);
        [self checkOffline:report];

        NRMAExceptionReportAdaptor* contextAdapter = [[[NRMAExceptionReportAdaptor alloc] initWithReport:report attributeValidator:_attributeValidator] autorelease];

        if (exceptionDictionary != nil) {
            [contextAdapter addAttributes:exceptionDictionary];
        }

        _controller->submit(report);
    }
}

- (std::map<std::string, std::shared_ptr<NewRelic::AttributeBase> >) getSessionAttributesResultMap {

    // Convert NSDictionary => std::map<std::string, std::shared_ptr<NewRelic::AttributeBase> >
    std::map<std::string, std::shared_ptr<NewRelic::AttributeBase> > resultMap;

    NSString *sessionAttributes = [analyticsParent sessionAttributeJSONString];
    if (sessionAttributes == nil || [sessionAttributes length] == 0) {
        return resultMap;
    }
    NSDictionary* dictionary = [NSJSONSerialization JSONObjectWithData:[sessionAttributes dataUsingEncoding:NSUTF8StringEncoding]
                                                               options:0
                                                                 error:nil];

    for (NSString *key in dictionary) {
        id value = [dictionary objectForKey:key];

        if ([value isKindOfClass:[NSNumber class]]) {
            NSNumber* number = (NSNumber*)value;
            if ([NewRelicInternalUtils isFloat:number]) {

                auto baseValue = NewRelic::Value::createValue([number floatValue]);

                auto attribute = std::make_shared<NewRelic::AttributeBase>(NewRelic::AttributeBase([key UTF8String],baseValue));

                resultMap.insert(std::make_pair([key UTF8String], attribute));
            }
            else if ([NewRelicInternalUtils isInteger:number]) {

                auto baseValue = NewRelic::Value::createValue([number longLongValue]);

                auto attribute = std::make_shared<NewRelic::AttributeBase>(NewRelic::AttributeBase([key UTF8String],baseValue));

                resultMap.insert(std::make_pair([key UTF8String], attribute));
            }
            else if ([NewRelicInternalUtils isBool:number]) {
                auto baseValue = NewRelic::Value::createValue([number boolValue]);

                auto attribute = std::make_shared<NewRelic::AttributeBase>(NewRelic::AttributeBase([key UTF8String],baseValue));

                resultMap.insert(std::make_pair([key UTF8String], attribute));
            }
        } else if ([value isKindOfClass:[NSString class]]) {
            auto baseValue = NewRelic::Value::createValue([value UTF8String]);

            auto attribute = std::make_shared<NewRelic::AttributeBase>(NewRelic::AttributeBase([key UTF8String],baseValue));

            resultMap.insert(std::make_pair([key UTF8String], attribute));
        } else if([value isKindOfClass:[NRMABool class]]) {
            long long longValue = ((NRMABool*)value).value;
            auto baseValue = NewRelic::Value::createValue(longValue);

            auto attribute = std::make_shared<NewRelic::AttributeBase>(NewRelic::AttributeBase([key UTF8String],baseValue));

            resultMap.insert(std::make_pair([key UTF8String], attribute));
        } else {
            continue;
        }
    }

    return resultMap;
}

@end
