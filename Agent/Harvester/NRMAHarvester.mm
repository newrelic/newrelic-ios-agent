//
//  NRMAHavester.m
//  NewRelicAgent
//
//  Created by Bryce Buchanan on 8/27/13.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import "NRMAHarvester.h"
#import "NRLogger.h"
#import "NRMAMeasurements.h"
#import "NRTimer.h"
#import "NRMAExceptionHandler.h"
#import "NRMATaskQueue.h"

#import "NRMAExceptionMetaDataStore.h"
#import "NRMAMetric.h"
#import "NRConstants.h"
#import "NRMAAppToken.h"
#include <Utilities/Application.hpp>
#import "NRMASupportMetricHelper.h"
#import "NRMAFlags.h"
#import "Constants.h"
#import "NewRelicAgentInternal.h"
#import "NewRelicInternalUtils.h"
#import "NRAutoLogCollector.h"

#define kNRSupportabilityResponseCode kNRSupportabilityPrefix @"/Collector/ResponseStatusCodes"

@interface NRMAHarvester (privateMethods)

- (void) uninitialized;
- (void) disabled;
- (void) connected;
- (void) disconnected;
- (NRMAHarvesterConfiguration*) configureFromCollector:(NRMAHarvestResponse*)response;
- (void) changeState:(NRMAHarvesterState)state;
- (BOOL) stateIn:(NRMAHarvesterState)state,...;
- (void) agentConfiguration:(NRMAAgentConfiguration*)agentConfiguration;
- (void) execute;
@end

@interface NRMAHarvester ()
@property(strong, atomic) NSMutableArray* harvestAwareObjects;
@end

@implementation NRMAHarvester
@synthesize currentState;

- (id) init
{
    self = [super init];
    if (self) {
        
        currentState = NRMA_HARVEST_UNINITIALIZED;
        connection = [[NRMAHarvesterConnection alloc] init];
        _harvestData = [[NRMAHarvestData alloc] init];
        self.harvestAwareObjects = [[NSMutableArray alloc] init];
        configuration = [self fetchHarvestConfiguration];
    }
    return self;
}

- (void) dealloc
{
    self.harvestAwareObjects = nil;
}

- (NSArray*) getHarvestAwareList
{
    return [self.harvestAwareObjects copy];
}

- (NRMAHarvesterConnection*)connection {
    return connection;
}
- (void) uninitialized
{
    if (_agentConfiguration == nil) {
        NRLOG_AGENT_ERROR(@"Agent configuration unavailable.");
        return;
    }

    NRMAConnectInformation* oldConnectionInfo = [self fetchConnectionInformation];
    NRMAConnectInformation* currentConnectionInfo = [NRMAAgentConfiguration connectionInformation];

    if (oldConnectionInfo!=nil) {
        if (![oldConnectionInfo isEqual:currentConnectionInfo]) {
            // Something changed, let's reconnect by clearing the harvest configs.
            if (![oldConnectionInfo.applicationInformation.appVersion isEqualToString:currentConnectionInfo.applicationInformation.appVersion]) {
                if ([oldConnectionInfo.deviceInformation.model isEqualToString:currentConnectionInfo.deviceInformation.model]) {
                    NRLOG_AGENT_VERBOSE(@"Detected new application version: %@ -> %@", oldConnectionInfo.applicationInformation.appVersion, currentConnectionInfo.applicationInformation.appVersion);
                    [[NSNotificationCenter defaultCenter] postNotificationName:kNRMADidChangeAppVersionNotification
                                                                        object:nil
                                                                      userInfo:@{kNRMACurrentVersionKey:currentConnectionInfo.applicationInformation.appVersion,
                                                                                 kNRMALastVersionKey:oldConnectionInfo.applicationInformation.appVersion}];
                } else {
                    NRLOG_AGENT_VERBOSE(@"detected upgrade, but device model was different.");
                    [[NSNotificationCenter defaultCenter] postNotificationName:kNRMADeviceDidChangeNotification
                                                                        object:nil];
                }
            }
            [self clearStoredHarvesterConfiguration];
        }
    }

    [self saveConnectionInformation:currentConnectionInfo];

    connection.connectionInformation = currentConnectionInfo;

    connection.applicationToken = _agentConfiguration.applicationToken.value;
    connection.collectorHost = _agentConfiguration.collectorHost;
    connection.useSSL = _agentConfiguration.useSSL;
    
    [self transition:NRMA_HARVEST_DISCONNECTED];
    
}
- (NRMAHarvesterConfiguration*) harvesterConfiguration
{
    return configuration;
}

- (void) transition:(NRMAHarvesterState)state
{
    // Only allow one transition per cycle.
    if (stateDidChange) {
        NRLOG_AGENT_VERBOSE(@"Ignoring multiple transition: %d",state);
        return;
    }
    
    if (self.currentState == state) {
        return;
    }
    switch (self.currentState) {
        case NRMA_HARVEST_UNINITIALIZED:
            if ([self stateIn:state,NRMA_HARVEST_DISCONNECTED,NRMA_HARVEST_DISABLED,nil])
                break;
            @throw [NSException exceptionWithName:(NSString*)kNRMAIllegalStateException
                                           reason:@"invalid state transition"
                                         userInfo:nil];
            
        case NRMA_HARVEST_DISCONNECTED:
            if ([self stateIn:state,NRMA_HARVEST_UNINITIALIZED,NRMA_HARVEST_CONNECTED,NRMA_HARVEST_DISABLED,nil])
                break;
            @throw [NSException exceptionWithName:(NSString*)kNRMAIllegalStateException
                                           reason:@"invalid state transition"
                                         userInfo:nil];
            
        case NRMA_HARVEST_CONNECTED:
            if ([self stateIn:state,NRMA_HARVEST_DISCONNECTED,NRMA_HARVEST_DISABLED,nil])
                break;
            @throw [NSException exceptionWithName:(NSString*)kNRMAIllegalStateException
                                           reason:@"invalid state transition"
                                         userInfo:nil];
            
        case NRMA_HARVEST_DISABLED:
        default:
            @throw [NSException exceptionWithName:(NSString*)kNRMAIllegalStateException
                                           reason:@"invalid state transition"
                                         userInfo:nil];
            break;
    }
    [self changeState:state];
}

- (void) disabled
{
    
}

- (void) addHarvestAwareObject:(id<NRMAHarvestAware>)harvestAware
{
    if (![harvestAware conformsToProtocol:@protocol(NRMAHarvestAware)]) {
        NRLOG_AGENT_ERROR(@"Attempted to add non-corforming harvest aware object");
        return;
    }
    @synchronized(self.harvestAwareObjects) {
        [self.harvestAwareObjects addObject:harvestAware];
    }
}

- (void) removeHarvestAwareObject:(id<NRMAHarvestAware>)harvestAware
{
    @synchronized(self.harvestAwareObjects){
        [self.harvestAwareObjects removeObject:harvestAware];
    }
}

- (void) configureHarvester:(NRMAHarvesterConfiguration*)harvestConfiguration
{
    NewRelic::Application::getInstance().setContext(NewRelic::ApplicationContext([[NSString stringWithFormat:@"%lld", harvestConfiguration.account_id] cStringUsingEncoding:NSUTF8StringEncoding],
                                                                                 [[NSString stringWithFormat:@"%lld", harvestConfiguration.application_id] cStringUsingEncoding:NSUTF8StringEncoding],
                                                                                 [[NSString stringWithFormat:@"%@", harvestConfiguration.trusted_account_key] cStringUsingEncoding:NSUTF8StringEncoding]));

    self.harvestData.dataToken = harvestConfiguration.data_token;
    connection.serverTimestamp = harvestConfiguration.server_timestamp;
    connection.crossProcessID  = harvestConfiguration.cross_process_id;
    connection.requestHeadersMap = harvestConfiguration.request_header_map;
}

- (NSString *) applicationIdentifierAsString
{
    return [[NRMAAgentConfiguration connectionInformation] toApplicationIdentifier];
}

- (BOOL) mayUseStoredConfiguration
{
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    NSString* storedAppId = [defaults objectForKey:kNRMAApplicationIdentifierKey];
    if (storedAppId && [storedAppId isKindOfClass:[NSString class]]) {
        NSString* runtimeAppId = [self applicationIdentifierAsString];
        return [runtimeAppId isEqualToString:storedAppId];
    } else {
        return NO;
    }
}

- (NRMAHarvesterConfiguration*) fetchHarvestConfiguration
{
    NRMAHarvesterConfiguration* harvestConfiguration = nil;
    if ([self mayUseStoredConfiguration]) {
        NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
        id object = [defaults objectForKey:kNRMAHarvesterConfigurationStoreKey];
        if ([object isKindOfClass:[NSDictionary class]]) {
            harvestConfiguration = [[NRMAHarvesterConfiguration alloc] initWithDictionary:(NSDictionary*)object];
        }
    }
    return harvestConfiguration;
}


- (NRMAConnectInformation*) fetchConnectionInformation
{
    NRMAConnectInformation* connectionInfo = nil;
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    id object = [defaults objectForKey:kNRMAConnectionInformationKey];
    if ([object isKindOfClass:[NSDictionary class]]) {
        connectionInfo = [[NRMAConnectInformation alloc] initWithDictionary:object];
    }
    return connectionInfo;
}

- (void) saveHarvesterConfiguration:(NRMAHarvesterConfiguration*)harvestConfiguration
{
    NRMA_setAgentId(harvestConfiguration.data_token.realAgentId);
    NRMA_setAccountId(harvestConfiguration.data_token.clusterAgentId);

    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    [defaults setValue:[harvestConfiguration asDictionary] forKey:(NSString*)kNRMAHarvesterConfigurationStoreKey];
    [defaults setValue:[self applicationIdentifierAsString] forKey:kNRMAApplicationIdentifierKey];
    [defaults synchronize];
}

- (void) clearStoredConnectionInformation
{
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    [defaults removeObjectForKey:kNRMAConnectionInformationKey];
    [defaults synchronize];
}

- (void) saveConnectionInformation:(NRMAConnectInformation*)connectionInformation
{
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    [defaults setValue:[connectionInformation asDictionary] forKey:kNRMAConnectionInformationKey];
    [defaults synchronize];
}

- (void) clearStoredHarvesterConfiguration
{
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    configuration.cross_process_id  = @"";
    [defaults removeObjectForKey:kNRMAHarvesterConfigurationStoreKey];
    [defaults synchronize];
}

- (void) clearStoredApplicationIdentifier {
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    [defaults removeObjectForKey:kNRMAApplicationIdentifierKey];
    [defaults synchronize];
}

- (NSString*) crossProcessID {
    return connection.crossProcessID;
}

- (void) connected
{
    NRTimer* harvestTimer = [[NRTimer alloc] init];

    // Harvest Config is fetched every time harvest is hit.
    NRMAHarvesterConfiguration* harvestConfig = [self fetchHarvestConfiguration];
    
    if (harvestConfig == nil) {
        NRLOG_AGENT_VERBOSE(@"No configuration.");
    }
    else if(![harvestConfig isValid] || ![harvestConfig.application_token isEqualToString:_agentConfiguration.applicationToken.value]) {
        [self clearStoredHarvesterConfiguration];

        [self transition:NRMA_HARVEST_DISCONNECTED];
        // Reconnect performed here.
        [self execute];
        return;
    }
    
    NRLOG_AGENT_VERBOSE(@"Harvester: connected");
    NRMAHarvestResponse* response = nil;
#ifndef  DISABLE_NRMA_EXCEPTION_WRAPPER
    @try {
#endif
        response = [connection sendData:self.harvestData];
#ifndef  DISABLE_NRMA_EXCEPTION_WRAPPER
    } @catch (NSException* exception) {
        if ([exception.name isEqualToString:NSInvalidArgumentException]) {
            NRLOG_AGENT_ERROR(@"harvest failed: harvestData == nil. This could just mean there was nothing to harvest.");
            [NRMAExceptionHandler logException:exception
                                         class:NSStringFromClass([connection class])
                                      selector:@"sendData:"];

            // The most likely cause of a crash here is bad json data. Let's clear out that data, and prevent this from happening again.
            [self.harvestData clear];

            return;
        }
    }
#endif
    switch (response.statusCode) {
        case FORBIDDEN:
        case INVALID_AGENT_ID:
            [self clearStoredHarvesterConfiguration];
            [self transition:NRMA_HARVEST_DISCONNECTED];
            // Reconnect performed here.
            [self execute];
            break;
        case UNSUPPORTED_MEDIA_TYPE:
        case ENTITY_TOO_LARGE:
            [self.harvestData clear];
            break;
        case CONFIGURATION_UPDATE:
            // WHEN RECEIVING A 409 status code from the /data endpoint we will PERFORM A CONNECT CALL TO REFRESH THE CONFIG.
            [self clearStoredHarvesterConfiguration];
            [self transition:NRMA_HARVEST_DISCONNECTED];
            // Reconnect performed here.
            [self execute];

            // Send Supportability metric when received 409 to indicate that a config update should happen or send it when actual /connect call finishes which refreshes the data.
            [NRMASupportMetricHelper enqueueConfigurationUpdateMetric];
            
            break;
        default:
            break;
    }
    //TODO: add addition collector response processing.
    if (response.isError) {
        // failure
        if([self checkOfflineAndPersist:response]) {
            // If the harvest was persisted for offline storage clear the harvest.
            [self.harvestData clear];
        } else {
            [self fireOnHarvestFailure];
        }
    } else {
        // success
        [self.harvestData clear];
        // If there was a successful harvest upload send the persisted offline payloads.
        [connection sendOfflineStorage];
    }
    //Supportability/MobileAgent/Collector/Harvest

    [harvestTimer stopTimer];
#ifndef  DISABLE_NRMA_EXCEPTION_WRAPPER
    @try {
#endif
        NSString *name;
#if TARGET_OS_WATCH
        if ([NewRelicAgentInternal sharedInstance].currentApplicationState == WKApplicationStateBackground) {
            name = kNRSupportabilityPrefix@"/Collector/Harvest/Background";
        }
#else
        if ([NewRelicAgentInternal sharedInstance].currentApplicationState == UIApplicationStateBackground) {
            name = kNRSupportabilityPrefix@"/Collector/Harvest/Background";
        }
#endif
        else {
            name = kNRSupportabilityPrefix@"/Collector/Harvest";
        }
        [NRMATaskQueue queue:[[NRMAMetric alloc] initWithName:name
                                                        value:[NSNumber numberWithDouble:harvestTimer.timeElapsedInSeconds]
                                                        scope:@""]];
#ifndef  DISABLE_NRMA_EXCEPTION_WRAPPER
    } @catch (NSException* exception) {
        [NRMAExceptionHandler logException:exception
                                     class:NSStringFromClass([self class])
                                  selector:NSStringFromSelector(_cmd)];
    }
#endif
    [self fireOnHarvestComplete];
}

- (BOOL) checkOfflineAndPersist:(NRMAHarvestResponse*) response {
    if (![NRMAFlags shouldEnableOfflineStorage]) {
        return false;
    }
    if([NRMAOfflineStorage checkErrorToPersist:response.error]) {
        NSError* error = nil;
        NSData* jsonData = [NRMAJSON dataWithJSONABLEObject:self.harvestData options:0 error:&error];
        if (error) {
            NRLOG_AGENT_ERROR(@"Failed to generate JSON");
            return false;
        }
        [connection.offlineStorage persistDataToDisk:jsonData];
        return true;
    }
    return false;
}

- (void) disconnected
{
    // Handle stored config.
    configuration = [self fetchHarvestConfiguration];

    // There was no stored config! set a reasonable default.
    if (configuration == nil) {
        configuration = [NRMAHarvesterConfiguration defaultHarvesterConfiguration];
    }

    [self handleLoggingConfigurationUpdate];

    // If we have a data token (config is valid), then skip the connect call.
    if (configuration.isValid && [configuration.application_token isEqualToString:_agentConfiguration.applicationToken.value]) {
        [NRMAMeasurements recordSessionStartMetric];
        [NRMASupportMetricHelper processDeferredMetrics];
        [self handleSessionReplayConfigurationUpdate];

        [self transitionToConnected:configuration];
        return;
    } else {
        // Invalidate cross process id for connect call.
        connection.crossProcessID = @"";
        configuration.cross_process_id = @"";
    }
    NRTimer* connectionTimer = [[NRTimer alloc] init];
    
    NRMAHarvestResponse* response;
    
#ifndef  DISABLE_NRMA_EXCEPTION_WRAPPER
    @try {
#endif
        response = [connection sendConnect];
#ifndef  DISABLE_NRMA_EXCEPTION_WRAPPER
    } @catch (NSException* exception) {
        NRLOG_AGENT_ERROR(@"harvest failed: connection failed while disconnecting");
        [NRMAExceptionHandler logException:exception
                                     class:NSStringFromClass([connection class])
                                  selector:@"sendConnect:"];
    }
#endif
    
    if (response == nil) {
        NRLOG_AGENT_ERROR(@"Unable to connect to the collector.");
        return;
    }
    
    if ([response isOK]) {
        configuration = [self configureFromCollector:response];
        if (configuration == nil) {
            NRLOG_AGENT_ERROR(@"Unable to configure Harvester using Collector Configuration");
            return;
        }
        // Configuration saved here.
        configuration.application_token = connection.applicationToken;

        [self handleLoggingConfigurationUpdate];
        [self handleSessionReplayConfigurationUpdate];

        [self saveHarvesterConfiguration:configuration];

        [NRMASupportMetricHelper processDeferredMetrics];

        [self transitionToConnected:configuration];
        
        [connectionTimer stopTimer];

#ifndef  DISABLE_NRMA_EXCEPTION_WRAPPER
        @try {
#endif
            [NRMATaskQueue queue:[[NRMAMetric alloc] initWithName:kNRSupportabilityPrefix@"/Collector/Connect"
                                                            value:[NSNumber numberWithDouble:connectionTimer.timeElapsedInSeconds]
                                                            scope:@""]];
#ifndef  DISABLE_NRMA_EXCEPTION_WRAPPER
        } @catch (NSException* exception) {
            [NRMAExceptionHandler logException:exception
                                         class:NSStringFromClass([self class])
                                      selector:NSStringFromSelector(_cmd)];
        }
#endif
        return;
    }
    [connectionTimer stopTimer];
    
    NRLOG_AGENT_VERBOSE(@"Harvest connect response: %d",response.statusCode);
#ifndef  DISABLE_NRMA_EXCEPTION_WRAPPER
    @try {
#endif
        [NRMATaskQueue queue:[[NRMAMetric alloc] initWithName:[NSString stringWithFormat:@"%@/%d",kNRSupportabilityResponseCode,response.statusCode]
                                                        value:@1
                                                        scope:@""]];
#ifndef  DISABLE_NRMA_EXCEPTION_WRAPPER
    } @catch (NSException* exception) {
        [NRMAExceptionHandler logException:exception
                                     class:NSStringFromClass([self class])
                                  selector:NSStringFromSelector(_cmd)];
    }
#endif
    switch ( response.statusCode) {
        case UNAUTHORIZED:
        case INVALID_AGENT_ID:
            break;
        case FORBIDDEN:
            if ([response isDisableCommand]) {
                NRLOG_AGENT_ERROR(@"Collector has commanded Agent to disable.");
                [self transition:NRMA_HARVEST_DISABLED];
                return;
            }
            NRLOG_AGENT_VERBOSE(@"Unexpected Collector response: FORBIDDEN");
            break;
        case UNSUPPORTED_MEDIA_TYPE:
        case ENTITY_TOO_LARGE:
            NRLOG_AGENT_VERBOSE(@"Invalid ConnectionInformation was sent to the Collector.");
            break;
        default:
            NRLOG_AGENT_VERBOSE(@"An unknown error occurred when connecting to the Collector.");
            break;
    }
    
    [self fireOnHarvestFailure];
}

- (void) transitionToConnected:(NRMAHarvesterConfiguration*)_configuration
{
     NRLOG_AGENT_VERBOSE(@"config: transitionToConnected");

    // Called from disconnected.
    [self configureHarvester:_configuration];
    
    [self transition:NRMA_HARVEST_CONNECTED];
    // Function will immediately send data.
    [self execute];
    return;
}

- (NRMAHarvesterConfiguration*) configureFromCollector:(NRMAHarvestResponse*)response
{
    NRMAHarvesterConfiguration* config = nil;
    @try {
        NSError* error = nil;        
        NSData *dataFromResp = [response.responseBody dataUsingEncoding:NSUTF8StringEncoding];

         NRLOG_AGENT_VERBOSE(@"Harvest config: %@", response.responseBody);

        id jsonObject = [NRMAJSON JSONObjectWithData:dataFromResp
                                               options:0
                                               error:&error];
        if (!error) {
            config = [[NRMAHarvesterConfiguration alloc] initWithDictionary:jsonObject];
        }
    }
    @catch (NSException *exception) {
        NRLOG_AGENT_ERROR(@"Unable to parse collector configuration: %@",[exception reason]);
    }
    return config;
}

- (void) changeState:(NRMAHarvesterState)state
{
    NRLOG_AGENT_VERBOSE(@"Harvester changing state: %d -> %d",self.currentState, state);
    currentState = state;
    stateDidChange = YES;
}
- (BOOL) stateIn:(NRMAHarvesterState)state,...
{
    BOOL returnValue = NO;
    va_list args;
    va_start(args, state);
    NRMAHarvesterState legalState;
    
    while ((legalState = va_arg(args, NRMAHarvesterState))) {
        if (state == legalState) {
            returnValue = YES;
        }
    }
    va_end(args);
    
    return returnValue;
    
}

- (void) setAgentConfiguration:(NRMAAgentConfiguration*)agentConfiguration
{
    _agentConfiguration = agentConfiguration;
}

- (void) execute
{
    // This sync will only be triggered when the agent attempts to
    // harvest on a background while the harvest is already running. Otherwise it will be business as usual.
    @synchronized(self) {
        NRLOG_AGENT_VERBOSE(@"Harvester State: %d",self.currentState);
        stateDidChange = NO;
        switch (self.currentState) {
            case NRMA_HARVEST_UNINITIALIZED:
                [self uninitialized];
                break;
            case NRMA_HARVEST_DISCONNECTED:
                [self disconnected];
                break;
            case NRMA_HARVEST_CONNECTED:
                [NRMASupportMetricHelper processDeferredMetrics];

                [self fireOnHarvestBefore];
                [self fireOnHarvest];
                [self connected];
                break;
            case NRMA_HARVEST_DISABLED:
                [self disabled];
                break;
            default:
                @throw [NSException exceptionWithName:(NSString*)kNRMAIllegalStateException
                                               reason:nil
                                             userInfo:nil];
        }
    }
}

#pragma mark - Harvest Aware

- (void) fireOnHarvestBefore
{
    @synchronized(self.harvestAwareObjects) {
        for (id<NRMAHarvestAware> hao in self.harvestAwareObjects) {
            if ([hao respondsToSelector:@selector(onHarvestBefore)]) {
#ifndef  DISABLE_NRMA_EXCEPTION_WRAPPER
                @try {
#endif
                    [hao onHarvestBefore];
#ifndef  DISABLE_NRMA_EXCEPTION_WRAPPER
                } @catch (NSException* exception) {
                    [NRMAExceptionHandler logException:exception
                                                 class:NSStringFromClass([hao class])
                                              selector:@"onHarvestBefore"];
                }
#endif
            }
        }
    }
}

- (void) fireOnHarvest
{
    @synchronized(self.harvestAwareObjects) {
        for (id<NRMAHarvestAware> hao in self.harvestAwareObjects) {
            if ([hao respondsToSelector:@selector(onHarvest)]) {
#ifndef  DISABLE_NRMA_EXCEPTION_WRAPPER
                @try {
#endif
                    [hao onHarvest];
#ifndef  DISABLE_NRMA_EXCEPTION_WRAPPER
                } @catch (NSException* exception) {
                    [NRMAExceptionHandler logException:exception
                                                 class:NSStringFromClass([hao class])
                                              selector:@"onHarvest"];
                }
#endif
            }
        }


        BOOL isSampled = [[NewRelicAgentInternal sharedInstance] sampleSeed] <= [configuration sampling_rate];
        // NRLOG_AGENT_VERBOSE(@"logging config: Sampling decision: %d, because seed <= rate: %f <= %f", isSampled, [[NewRelicAgentInternal sharedInstance] sampleSeed], [configuration sampling_rate]);
        if (isSampled && [NRMAFlags shouldEnableLogReporting]) {
            // Do log upload
            [NRLogger enqueueLogUpload];
        }
    }
}

- (void) fireOnHarvestComplete
{
    
    @synchronized(self.harvestAwareObjects) {
        for (id<NRMAHarvestAware> hao in self.harvestAwareObjects) {
            if ([hao respondsToSelector:@selector(onHarvestComplete)]) {
#ifndef  DISABLE_NRMA_EXCEPTION_WRAPPER
                @try {
#endif
                    [hao onHarvestComplete];
#ifndef  DISABLE_NRMA_EXCEPTION_WRAPPER
                } @catch (NSException* excep) {
                    [NRMAExceptionHandler logException:excep
                                                 class:NSStringFromClass([hao class])
                                              selector:@"onHarvestComplete"];
                }
#endif
            }
        }
    }
}

- (void) fireOnHarvestFailure
{
    @synchronized(self.harvestAwareObjects) {
        for (id<NRMAHarvestAware> hao in self.harvestAwareObjects) {
            if ([hao respondsToSelector:@selector(onHarvestError)]) {
#ifndef  DISABLE_NRMA_EXCEPTION_WRAPPER
                @try {
#endif
                    [hao onHarvestError];
#ifndef  DISABLE_NRMA_EXCEPTION_WRAPPER
                } @catch (NSException* exception) {
                    [NRMAExceptionHandler logException:exception
                                                 class:NSStringFromClass([hao class])
                                              selector:@"onHarvestError"];
                }
#endif
            }
        }
    }
}

- (void) fireOnHarvestStart
{
    @synchronized(self.harvestAwareObjects) {
        for (id<NRMAHarvestAware> hao in self.harvestAwareObjects) {
            if ([hao respondsToSelector:@selector(onHarvestStart)]) {
#ifndef  DISABLE_NRMA_EXCEPTION_WRAPPER
                @try {
#endif
                    [hao onHarvestStart];
#ifndef  DISABLE_NRMA_EXCEPTION_WRAPPER
                } @catch (NSException* exception) {
                    [NRMAExceptionHandler logException:exception
                                                 class:NSStringFromClass([hao class])
                                              selector:@"onHarvestStart"];
                }
#endif
            }
        }
    }
}

- (void) stop
{
    @synchronized(self.harvestAwareObjects) {
        for (id<NRMAHarvestAware> hao in self.harvestAwareObjects) {
            if ([hao respondsToSelector:@selector(onHarvestStop)]) {
#ifndef  DISABLE_NRMA_EXCEPTION_WRAPPER
                @try {
#endif
                    [hao onHarvestStop];
#ifndef  DISABLE_NRMA_EXCEPTION_WRAPPER
                } @catch (NSException* exception) {
                    [NRMAExceptionHandler logException:exception
                                                 class:NSStringFromClass([hao class])
                                              selector:@"onHarvestStop"];
                }
#endif
            }
        }
    }
}

- (void) setMaxOfflineStorageSize:(NSUInteger) size {
    [connection setMaxOfflineStorageSize:size];
}

- (void) handleLoggingConfigurationUpdate {
    // Code for dynamically enabling or disabling remote logging at runtime based on the state of configuration.log_reporting_enabled and the existing state of NRFlags.NRFeatureFlag_LogReporting

    // This if/else chain should only be entered if log_reporting was found in the config
    if (configuration.has_log_reporting_config) {
        if (configuration.log_reporting_enabled) {
            if ([NRMAFlags shouldEnableAutoCollectLogs] && ![NewRelicInternalUtils isDebuggerAttached]){
                [NRAutoLogCollector redirectStandardOutputAndError];
                // it is required to enable NRLogTargetFile when using LogReporting.
                [NRLogger setLogTargets:NRLogTargetFile];
            } else {
                [NRLogger setLogTargets:NRLogTargetConsole | NRLogTargetFile];
            }
            
            // Parse NSString into NRLogLevel
            NRLogLevels level = [NRLogger stringToLevel: configuration.log_reporting_level];
            [NRLogger setRemoteLogLevel:level];

             NRLOG_AGENT_DEBUG(@"config: Has log reporting ENABLED w/ level = %@",configuration.log_reporting_level);

            [NRMAFlags enableFeatures:NRFeatureFlag_LogReporting];
        }
        // OVERWRITE user selected value for LogReporting.
        else {
             NRLOG_AGENT_DEBUG(@"config: Has log reporting DISABLED");
            if ([NRMAFlags shouldEnableAutoCollectLogs]) {
                [NRAutoLogCollector restoreStandardOutputAndError];
            }
            [NRLogger setLogTargets:NRLogTargetConsole];

            [NRMAFlags disableFeatures:NRFeatureFlag_LogReporting];
        }
    }
    else {
        // No Log Reporting Config Detected, not automating feature flags or logging config.
         NRLOG_AGENT_DEBUG(@"no config: No Config Detected, not automating feature flags or logging config.");
    }
}

- (void) handleSessionReplayConfigurationUpdate {
    // if it was on and now its off stop MSR

    // if it was off and now its on start MSR
    if (configuration.has_session_replay_config) {
        if (configuration.session_replay_enabled) {
            
            NRLOG_AGENT_DEBUG(@"config: Has SESSION REPLAY ENABLED");

            [[NewRelicAgentInternal sharedInstance] sessionReplayStart];
        }
        else {
            NRLOG_AGENT_DEBUG(@"config: SESSION REPLAY DISABLED");
            [[NewRelicAgentInternal sharedInstance] sessionReplayDisabled];
        }
    }
    // No replay config at all, don't mess with replay
    else {
        NRLOG_AGENT_DEBUG(@"no config: No SESSION REPLAY Config Detected.");
        [[NewRelicAgentInternal sharedInstance] sessionReplayDisabled];
    }

}

@end
