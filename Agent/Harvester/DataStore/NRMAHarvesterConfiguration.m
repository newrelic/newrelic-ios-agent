//
//  NRMAHavesterConfiguration.m
//  NewRelicAgent
//
//  Created by Bryce Buchanan on 8/27/13.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import "NRMAHarvesterConfiguration.h"
#import "NRLogger.h"
#import "NRConstants.h"
#import "NRMAAgentConfiguration.h"

@implementation NRMAHarvesterConfiguration

- (id) initWithDictionary:(NSDictionary*)dict
{
    self = [super init];
    if (self) {
        self.application_token = [dict valueForKey:kNRMA_LICENSE_KEY];

        if ([dict objectForKey:kNRMA_COLLECT_NETWORK_ERRORS]) {
            self.collect_network_errors = [[dict valueForKey:kNRMA_COLLECT_NETWORK_ERRORS] boolValue];
        }
        else {
            self.collect_network_errors = NRMA_DEFAULT_COLLECT_NETWORK_ERRORS;
        }

        if ([dict valueForKey:kNRMA_CROSS_PROCESS_ID]) {
            self.cross_process_id = [dict valueForKey:kNRMA_CROSS_PROCESS_ID];
        }
        else {
            self.cross_process_id = @"";
        }

        if ([dict objectForKey:kNRMA_DATA_REPORT_PERIOD]) {
            self.data_report_period = [[dict valueForKey:kNRMA_DATA_REPORT_PERIOD] intValue];
        }
        else {
            self.data_report_period = NRMA_DEFAULT_REPORT_PERIOD;
        }

        self.data_token = [[NRMADataToken alloc] init];
        self.data_token.clusterAgentId  = [[[dict valueForKey:kNRMA_DATA_TOKEN] objectAtIndex:0] longLongValue];
        self.data_token.realAgentId = [[[dict valueForKey:kNRMA_DATA_TOKEN] objectAtIndex:1] longLongValue];

        if ([dict objectForKey:kNRMA_ERROR_LIMIT]) {
            self.error_limit = [[dict valueForKey:kNRMA_ERROR_LIMIT] intValue];
        }
        else {
            self.error_limit = NRMA_DEFAULT_ERROR_LIMIT;
        }

        if ([dict objectForKey:kNRMA_REPORT_MAX_TRANSACTION_AGE]) {

            self.report_max_transaction_age = [[dict valueForKey:kNRMA_REPORT_MAX_TRANSACTION_AGE] intValue];
        }
        else {
            self.report_max_transaction_age = NRMA_DEFAULT_MAX_TRANSACTION_AGE;
        }
        if ([dict objectForKey:kNRMA_REPORT_MAX_TRANSACTION_COUNT]) {
            self.report_max_transaction_count = [[dict valueForKey:kNRMA_REPORT_MAX_TRANSACTION_COUNT]intValue];
        }
        else {
            self.report_max_transaction_count = NRMA_DEFAULT_MAX_TRANSACTION_COUNT;
        }

        if ([dict objectForKey:kNRMA_RESPONSE_BODY_LIMIT]) {
            self.response_body_limit = [[dict valueForKey:kNRMA_RESPONSE_BODY_LIMIT] intValue];
        }
        else {
            self.response_body_limit = NRMA_DEFAULT_RESPONSE_BODY_LIMIT;
        }

        self.server_timestamp = [[dict valueForKey:kNRMA_SERVER_TIMESTAMP] longLongValue];
        
        if ([dict objectForKey:kNRMA_STACK_TRACE_LIMIT]) {
            self.stack_trace_limit = [[dict valueForKey:kNRMA_STACK_TRACE_LIMIT] intValue];
        }
        else {
            self.stack_trace_limit = NRMA_DEFAULT_STACK_TRACE_LIMIT;
        }
        if ([dict objectForKey:kNRMA_AT_MAX_SIZE]) {
            self.activity_trace_max_size =[[dict valueForKey:kNRMA_AT_MAX_SIZE] intValue];
        }
        else {
            self.activity_trace_max_size = NRMA_DEFAULT_ACTIVITY_TRACE_MAX_SIZE;
        }

        self.at_capture = [[NRMATraceConfigurations alloc] initWithArray:[dict valueForKey:kNRMA_AT_CAPTURE]];
        self.activity_trace_min_utilization = [[dict valueForKey:KNRMA_AT_MIN_UTILIZATION] doubleValue];
        if ([dict objectForKey:kNRMA_ENCODING_KEY]) {
            self.encoding_key = [dict valueForKey:kNRMA_ENCODING_KEY];
        }
        else {
            self.encoding_key = @"";
        }

        self.account_id = [[dict valueForKey:kNRMA_ACCOUNT_ID] longLongValue];

        self.application_id = self.data_token.clusterAgentId;

        self.trusted_account_key = [dict valueForKey:kNRMA_TRUSTED_ACCOUNT_KEY];

        if ([dict objectForKey:kNRMA_ENTITY_GUID_KEY]) {
            self.entity_guid = [dict valueForKey:kNRMA_ENTITY_GUID_KEY];
        } else {
            self.entity_guid = @"";
        }

        // begin parsing log reporting section.
        if ([dict objectForKey:kNRMA_CONFIG_KEY]) {
            self.has_log_reporting_config = YES;

            id innerDict = [[dict objectForKey:kNRMA_CONFIG_KEY] objectForKey:kNRMA_LOG_REPORTING_KEY];

            BOOL enabled = [innerDict[kNRMA_LOG_REPORTING_ENABLED_KEY] boolValue];
            if (enabled) {
                NSString *level = (NSString*) innerDict[kNRMA_LOG_REPORTING_LEVEL_KEY];
                self.log_reporting_enabled = enabled;
                self.log_reporting_level = level;
            }
            else {
                self.log_reporting_enabled = NO;
                self.log_reporting_level = kNRMA_LOG_REPORTING_LEVEL_DEFAULT;
                self.sampling_rate = 100.0;

            }
            if ([innerDict objectForKey: kNRMA_LOG_REPORTING_SAMPLE_RATE_KEY]) {
                self.sampling_rate =  [innerDict[kNRMA_LOG_REPORTING_SAMPLE_RATE_KEY] doubleValue];
            }
            else {
                self.sampling_rate = 100.0;
            }
        }
        else {
            self.log_reporting_enabled = NO;
            self.has_log_reporting_config = NO;
            self.log_reporting_level = kNRMA_LOG_REPORTING_LEVEL_DEFAULT;
            self.sampling_rate = 100.0;
        }
        // end parsing log reporting section.

        // Begin parsing request headers map.
        if ([dict objectForKey:KNRMA_REQUEST_HEADER_MAP_KEY]) {
            self.request_header_map = [dict objectForKey:KNRMA_REQUEST_HEADER_MAP_KEY];
        }
        else {
            self.request_header_map = [NSDictionary dictionary];
        }
        // End parsing request headers map.

        // The collector does not currently send down this key, but we still want a sane default
        if ([dict objectForKey:kNRMA_AT_MAX_SEND_ATTEMPTS]) {
            self.activity_trace_max_send_attempts = [[dict valueForKey:kNRMA_AT_MAX_SEND_ATTEMPTS] intValue];
        } else {
            self.activity_trace_max_send_attempts = NRMA_DEFAULT_ACTIVITY_TRACE_MAX_SEND_ATTEMPTS;
        }


        // session replay configuration parsing
        if ([dict objectForKey:kNRMA_CONFIG_KEY]) {
            id innerDict = [[dict objectForKey:kNRMA_CONFIG_KEY] objectForKey:kNRMA_SESSION_REPLAY_CONFIG_KEY];

            self.has_session_replay_config = YES;

            BOOL enabled = [innerDict[kNRMA_SESSION_REPLAY_CONFIG_ENABLED_KEY] boolValue];
            if (enabled) {
                self.session_replay_enabled = YES;

            }
            else {
                self.session_replay_enabled = NO;

            }

            // handle sample rate

            if ([innerDict objectForKey: kNRMA_SESSION_REPLAY_CONFIG_SAMPLERATE_KEY]) {
                self.session_replay_sampling_rate =  [innerDict[kNRMA_SESSION_REPLAY_CONFIG_SAMPLERATE_KEY] doubleValue];
            }
            else {
                self.session_replay_sampling_rate = 100.0;
            }

            // handle error sample rate

            if ([innerDict objectForKey: kNRMA_SESSION_REPLAY_CONFIG_ERRORRATE_KEY]) {
                self.session_replay_error_sampling_rate =  [innerDict[kNRMA_SESSION_REPLAY_CONFIG_ERRORRATE_KEY] doubleValue];
            }
            else {
                self.session_replay_error_sampling_rate = 100.0;
            }

            // Handle mode string
            if ([innerDict objectForKey: kNRMA_SESSION_REPLAY_CONFIG_MODE_KEY]) {
                self.session_replay_mode =  innerDict[kNRMA_SESSION_REPLAY_CONFIG_MODE_KEY];
            }
            else {
                self.session_replay_mode = SessionReplayMaskingModeCustom;
            }


            // Handle the BOOL masking options.
            if ([innerDict objectForKey: kNRMA_SESSION_REPLAY_CONFIG_maskApplicationText_KEY]) {
                self.session_replay_maskApplicationText =  [innerDict[kNRMA_SESSION_REPLAY_CONFIG_maskApplicationText_KEY] boolValue];

            }
            else {
                self.session_replay_maskApplicationText = YES;
            }

            if ([innerDict objectForKey: kNRMA_SESSION_REPLAY_CONFIG_maskUserInputText_KEY]) {
                self.session_replay_maskUserInputText =  [innerDict[kNRMA_SESSION_REPLAY_CONFIG_maskUserInputText_KEY] boolValue];

            }
            else {
                self.session_replay_maskUserInputText = YES;
            }

            if ([innerDict objectForKey: kNRMA_SESSION_REPLAY_CONFIG_maskAllUserTouches_KEY]) {
                self.session_replay_maskAllUserTouches =  [innerDict[kNRMA_SESSION_REPLAY_CONFIG_maskAllUserTouches_KEY] boolValue];

            }
            else {
                self.session_replay_maskAllUserTouches =  NO;
            }

            if ([[innerDict objectForKey: kNRMA_SESSION_REPLAY_CONFIG_maskAllUserTouches_KEY] boolValue]) {
                self.session_replay_maskAllImages =  innerDict[kNRMA_SESSION_REPLAY_CONFIG_maskAllImages_KEY];

            }
            else {
                self.session_replay_maskAllImages =  YES;

            }
            
            //When in default mode, the user does not have the ability to change the booleans, we use the defaults for the boolean
            //input text mask - true
            //application text mask - true
            //image placeholders - true
            //hide taps and touches - false
            if (self.session_replay_mode == SessionReplayMaskingModeDefault){
                self.session_replay_maskApplicationText = YES;
                self.session_replay_maskUserInputText = YES;
                self.session_replay_maskAllImages = YES;
                self.session_replay_maskAllUserTouches = NO;
            }

            // Masked
            // New masking rules should be added to the local config
            [self addMaskedAccessibilityIdentifiers: [NRMAAgentConfiguration local_session_replay_maskedAccessibilityIdentifiers]];
            [self addMaskedClassNames:[NRMAAgentConfiguration local_session_replay_maskedClassNames]];
            
            // Unmasked
            // New unmasking rules replace the local config
            [self addUnmaskedClassNames: [NRMAAgentConfiguration local_session_replay_unmaskedClassNames]];
            [self addUnmaskedAccessibilityIdentifiers: [NRMAAgentConfiguration local_session_replay_unmaskedAccessibilityIdentifiers]];
            
            self.session_replay_customRules = [NSMutableArray array];
            
            // Handle the custom rule options.
            NSArray *customRulesArray = innerDict[kNRMA_SESSION_REPLAY_CONFIG_customMaskingRules_KEY];
            if (customRulesArray && [customRulesArray isKindOfClass:[NSArray class]]) {
                for (NSDictionary *ruleDict in customRulesArray) {
                    SessionReplayCustomMaskingRule *rule = [[SessionReplayCustomMaskingRule alloc] initWithDictionary:ruleDict];
                    [self.session_replay_customRules addObject:rule];
                    
                    if ([rule.identifier isEqual: kNRMA_SESSION_REPLAY_CONFIG_TAG_KEY] && [rule.type isEqual: kNRMA_SESSION_REPLAY_CONFIG_MASK_KEY]) {
                        [self addMaskedAccessibilityIdentifiers: rule.name];
                        
                    } else if ([rule.identifier isEqual: kNRMA_SESSION_REPLAY_CONFIG_CLASS_KEY] && [rule.type isEqual: kNRMA_SESSION_REPLAY_CONFIG_MASK_KEY]) {
                        [self addMaskedClassNames: rule.name];
                        
                    } else if ([rule.identifier isEqual: kNRMA_SESSION_REPLAY_CONFIG_TAG_KEY] && [rule.type isEqual: kNRMA_SESSION_REPLAY_CONFIG_UNMASK_KEY]) {
                        [self addUnmaskedAccessibilityIdentifiers: rule.name];
                        
                    } else if ([rule.identifier isEqual: kNRMA_SESSION_REPLAY_CONFIG_CLASS_KEY] && [rule.type isEqual: kNRMA_SESSION_REPLAY_CONFIG_UNMASK_KEY]) {
                        [self addUnmaskedClassNames: rule.name];
                        
                    }
                }
            }

        }
        else {

            self.has_session_replay_config = NO;
            self.session_replay_enabled = NO;
            self.session_replay_sampling_rate = 100.0;
            self.session_replay_error_sampling_rate = 100.0;
            self.session_replay_mode = SessionReplayMaskingModeCustom;
            self.session_replay_maskApplicationText = true;
            self.session_replay_maskUserInputText = true;
            self.session_replay_maskAllUserTouches = true;
            self.session_replay_maskAllImages = true;

        }

        // end session replay configuration parsing

    }
    return self;
}

+ (id) defaultHarvesterConfiguration
{
    NRMAHarvesterConfiguration *configuration = [[NRMAHarvesterConfiguration alloc] init];
    configuration.collect_network_errors = NRMA_DEFAULT_COLLECT_NETWORK_ERRORS;
    configuration.data_report_period = NRMA_DEFAULT_REPORT_PERIOD;
    configuration.error_limit = NRMA_DEFAULT_ERROR_LIMIT;
    configuration.report_max_transaction_age = NRMA_DEFAULT_MAX_TRANSACTION_AGE;
    configuration.report_max_transaction_count = NRMA_DEFAULT_MAX_TRANSACTION_COUNT;
    configuration.response_body_limit = NRMA_DEFAULT_RESPONSE_BODY_LIMIT;
    configuration.stack_trace_limit = NRMA_DEFAULT_STACK_TRACE_LIMIT;
    configuration.activity_trace_max_size = NRMA_DEFAULT_ACTIVITY_TRACE_MAX_SIZE;
    configuration.activity_trace_max_send_attempts = NRMA_DEFAULT_ACTIVITY_TRACE_MAX_SEND_ATTEMPTS;
    configuration.activity_trace_min_utilization = NRMA_DEFAULT_ACTIVITY_TRACE_MIN_UTILIZATION;
    configuration.trusted_account_key = @"";
    configuration.at_capture = [NRMATraceConfigurations defaultTraceConfigurations];

    configuration.entity_guid = @"";
    configuration.log_reporting_level = kNRMA_LOG_REPORTING_LEVEL_DEFAULT;
    configuration.has_log_reporting_config = YES;
    configuration.log_reporting_enabled = YES;
    configuration.sampling_rate = 100.0;
    configuration.request_header_map = [NSDictionary dictionary];


    // Session Replay Default harvester Configuration

    configuration.has_session_replay_config = YES;

    configuration.session_replay_enabled = YES;

    // handle double
    configuration.session_replay_sampling_rate = 100.0;

    // handle double
    configuration.session_replay_error_sampling_rate = 100.0;

    // Handle mode string
    configuration.session_replay_mode = SessionReplayMaskingModeCustom;

    configuration.session_replay_maskApplicationText = true;
    configuration.session_replay_maskUserInputText = true;
    configuration.session_replay_maskAllUserTouches = true;
    configuration.session_replay_maskAllImages = true;

    // Masked
    configuration.session_replay_maskedAccessibilityIdentifiers = [NRMAAgentConfiguration local_session_replay_maskedAccessibilityIdentifiers];
    configuration.session_replay_maskedClassNames = [NRMAAgentConfiguration local_session_replay_maskedClassNames];
    // Unmasked
    configuration.session_replay_unmaskedClassNames = [NRMAAgentConfiguration local_session_replay_unmaskedClassNames];
    configuration.session_replay_unmaskedAccessibilityIdentifiers = [NRMAAgentConfiguration local_session_replay_unmaskedAccessibilityIdentifiers];

    // Session Replay Default harvester Configuration

    return configuration;
}

- (BOOL) isValid
{
    return self.data_token.isValid && self.account_id > 0 && self.application_id > 0;
}

- (NSDictionary*) asDictionary
{
    NSMutableDictionary* dictionary = [[NSMutableDictionary alloc] initWithCapacity:15];
    dictionary[kNRMA_LICENSE_KEY] = self.application_token;
    dictionary[kNRMA_COLLECT_NETWORK_ERRORS] = @(self.collect_network_errors);
    if ([self.cross_process_id length]) {
        dictionary[kNRMA_CROSS_PROCESS_ID] = self.cross_process_id;
     }
    
    dictionary[kNRMA_DATA_REPORT_PERIOD] = @(self.data_report_period);
    
    dictionary[kNRMA_DATA_TOKEN] = @[@(self.data_token.clusterAgentId),
            @(self.data_token.realAgentId)];
    
    dictionary[kNRMA_ERROR_LIMIT] = @(self.error_limit);
    dictionary[kNRMA_REPORT_MAX_TRANSACTION_AGE] = @(self.report_max_transaction_age);
    dictionary[kNRMA_REPORT_MAX_TRANSACTION_COUNT] = @(self.report_max_transaction_count);
    dictionary[kNRMA_RESPONSE_BODY_LIMIT] = @(self.response_body_limit);
    dictionary[kNRMA_SERVER_TIMESTAMP] = @(self.server_timestamp);
    dictionary[kNRMA_STACK_TRACE_LIMIT] = @(self.stack_trace_limit);
    dictionary[kNRMA_AT_MAX_SIZE] = @(self.activity_trace_max_size);
    dictionary[kNRMA_AT_MAX_SEND_ATTEMPTS] = @(self.activity_trace_max_send_attempts);
    dictionary[KNRMA_AT_MIN_UTILIZATION] = @(self.activity_trace_min_utilization);
    dictionary[kNRMA_AT_CAPTURE] = @[[NSNumber numberWithInt:self.at_capture.maxTotalTraceCount], self.at_capture.activityTraceConfigurations?:@[]];
    dictionary[kNMRA_APPLICATION_ID] = @(self.application_id);
    dictionary[kNRMA_ACCOUNT_ID] = @(self.account_id);

    if ([self.encoding_key length]) {
        dictionary[kNRMA_ENCODING_KEY] = self.encoding_key;
    }

    if ([self.trusted_account_key length]) {
        dictionary[kNRMA_TRUSTED_ACCOUNT_KEY] = self.trusted_account_key;
    }

    if ([self.entity_guid length]) {
        dictionary[kNRMA_ENTITY_GUID_KEY] = self.entity_guid;
    }

    if (self.has_log_reporting_config) {
        dictionary[kNRMA_CONFIG_KEY] = @{kNRMA_LOG_REPORTING_KEY: @{kNRMA_LOG_REPORTING_ENABLED_KEY: @(self.log_reporting_enabled), kNRMA_LOG_REPORTING_LEVEL_KEY: self.log_reporting_level, kNRMA_LOG_REPORTING_SAMPLE_RATE_KEY: @(self.sampling_rate)}};
    }

    if ([self.request_header_map count]) {
        dictionary[KNRMA_REQUEST_HEADER_MAP_KEY] = self.request_header_map;
    }
    else {
        dictionary[KNRMA_REQUEST_HEADER_MAP_KEY] = [NSDictionary dictionary];
    }


    if (self.has_session_replay_config) {
        dictionary[kNRMA_CONFIG_KEY] =  @{kNRMA_SESSION_REPLAY_CONFIG_KEY: @{kNRMA_SESSION_REPLAY_CONFIG_ENABLED_KEY: @(self.session_replay_enabled),
                                             kNRMA_SESSION_REPLAY_CONFIG_MODE_KEY: self.session_replay_mode,
                                             kNRMA_SESSION_REPLAY_CONFIG_SAMPLERATE_KEY : @(self.session_replay_sampling_rate),
                                             kNRMA_SESSION_REPLAY_CONFIG_ERRORRATE_KEY : @(self.session_replay_error_sampling_rate),
                                             kNRMA_SESSION_REPLAY_CONFIG_maskApplicationText_KEY: @(self.session_replay_maskApplicationText),
                                            kNRMA_SESSION_REPLAY_CONFIG_maskUserInputText_KEY: @(self.session_replay_maskUserInputText),
                                            kNRMA_SESSION_REPLAY_CONFIG_maskAllUserTouches_KEY: @(self.session_replay_maskAllUserTouches),
                                            kNRMA_SESSION_REPLAY_CONFIG_maskAllImages_KEY: @(self.session_replay_maskAllImages),
                                                                             kNRMA_SESSION_REPLAY_CONFIG_customMaskingRules_KEY: [self serializeSessionReplayCustomRules],
        }};
    }


    return dictionary;
}

- (NSArray *)serializeSessionReplayCustomRules {
    NSMutableArray *serializedRules = [NSMutableArray array];
    
    for (SessionReplayCustomMaskingRule *rule in self.session_replay_customRules) {
        NSMutableDictionary *ruleDict = [NSMutableDictionary dictionary];
        
        if (rule.type) {
            ruleDict[kNRMA_SESSION_REPLAY_CONFIG_TYPE_KEY] = rule.type;
        }
        
        if (rule.operatorName) {
            ruleDict[kNRMA_SESSION_REPLAY_CONFIG_OPERATOR_KEY] = rule.operatorName;
        }
        
        if (rule.name) {
            ruleDict[kNRMA_SESSION_REPLAY_CONFIG_NAME_KEY] = rule.name;
        }
        
        if (rule.identifier) {
            ruleDict[kNRMA_SESSION_REPLAY_CONFIG_IDENTIFIER_KEY] = rule.identifier;
        }
        
        [serializedRules addObject:ruleDict];
    }
    
    return serializedRules;
}

- (void)addMaskedAccessibilityIdentifiers:(NSArray *)array {
    if (array.count > 0) {
        @synchronized(_session_replay_maskedAccessibilityIdentifiers) {
            [_session_replay_maskedAccessibilityIdentifiers addObjectsFromArray:array];
            NRLOG_AGENT_VERBOSE(@"Added masked accessibility identifier: %@", array);
        }
    }
}

- (void)removeMaskedAccessibilityIdentifier:(NSString *)identifier {
    if (identifier.length > 0) {
        @synchronized(_session_replay_maskedAccessibilityIdentifiers) {
            [_session_replay_maskedAccessibilityIdentifiers removeObject:identifier];
            NRLOG_AGENT_VERBOSE(@"Removed masked accessibility identifier: %@", identifier);
        }
    }
}

- (void)addMaskedClassNames:(NSArray *)array {
    if (array.count > 0) {
        @synchronized(_session_replay_maskedClassNames) {
            [_session_replay_maskedClassNames addObjectsFromArray:array];
            NRLOG_AGENT_VERBOSE(@"Added masked class name: %@", array);
        }
    }
}

- (void)removeMaskedClassName:(NSString *)className {
    if (className.length > 0) {
        @synchronized(_session_replay_maskedClassNames) {
            [_session_replay_maskedClassNames removeObject:className];
            NRLOG_AGENT_VERBOSE(@"Removed masked class name: %@", className);
        }
    }
}

- (void)addUnmaskedAccessibilityIdentifiers:(NSArray *)array {
    if (array.count > 0) {

        @synchronized(_session_replay_unmaskedAccessibilityIdentifiers) {
            [_session_replay_unmaskedAccessibilityIdentifiers addObjectsFromArray:array];
            NRLOG_AGENT_VERBOSE(@"Added unmasked accessibility identifier: %@", array);
        }
    }
}

- (void)removeUnmaskedAccessibilityIdentifier:(NSString *)identifier {
    if (identifier.length > 0) {
        @synchronized(_session_replay_unmaskedAccessibilityIdentifiers) {
            [_session_replay_unmaskedAccessibilityIdentifiers removeObject:identifier];
            NRLOG_AGENT_VERBOSE(@"Removed unmasked accessibility identifier: %@", identifier);
        }
    }
}

- (void)addUnmaskedClassNames:(NSArray *)array {

    if (array.count > 0) {
        @synchronized(_session_replay_unmaskedClassNames) {
            [_session_replay_unmaskedClassNames addObjectsFromArray:array];
            NRLOG_AGENT_VERBOSE(@"Added unmasked class name: %@", array);
        }
    }
}

- (void)removeUnmaskedClassName:(NSString *)className {
    if (className.length > 0) {
        @synchronized(_session_replay_unmaskedClassNames) {
            [_session_replay_unmaskedClassNames removeObject:className];
            NRLOG_AGENT_VERBOSE(@"Removed unmasked class name: %@", className);
        }
    }
}

- (BOOL) isEqual:(id)object {
    if (self == object) return YES;
    if (object == nil || ![object isKindOfClass:self.class]) return NO;
    NRMAHarvesterConfiguration* that = (NRMAHarvesterConfiguration*)object;
    if (self.application_token != that.application_token) return NO;
    if (self.collect_network_errors != that.collect_network_errors) return NO;
    if (self.data_report_period != that.data_report_period) return NO;
    if (self.error_limit != that.error_limit) return NO;
    if (self.report_max_transaction_age != that.report_max_transaction_age)return NO;
    if (self.report_max_transaction_count != that.report_max_transaction_count) return NO;
    if (self.response_body_limit != that.response_body_limit) return NO;
    if (self.server_timestamp != that.server_timestamp) return NO;
    if (self.stack_trace_limit != that.stack_trace_limit) return NO;
    if (![self.cross_process_id isEqualToString:that.cross_process_id]) return NO;
    if (self.activity_trace_max_size != that.activity_trace_max_size) return NO;
    if (self.activity_trace_max_send_attempts != that.activity_trace_max_send_attempts) return NO;
    if (self.activity_trace_min_utilization != that.activity_trace_min_utilization) return NO;
    if (self.account_id != that.account_id) return NO;
    if (self.application_id != that.application_id) return NO;
    if (![self.encoding_key isEqualToString:that.encoding_key]) return NO;
    
    if (![self.entity_guid isEqualToString:that.entity_guid]) return NO;

    if (self.sampling_rate != that.sampling_rate) return NO;
    if (![self.log_reporting_level isEqualToString:that.log_reporting_level]) return NO;
    if (self.log_reporting_enabled != that.log_reporting_enabled) return NO;
    if (self.has_log_reporting_config != that.has_log_reporting_config) return NO;
    if (self.request_header_map != that.request_header_map) return NO;


    // session replay equality
    if (self.session_replay_sampling_rate != that.session_replay_sampling_rate) return NO;
    if (![self.session_replay_mode isEqualToString:that.session_replay_mode]) return NO;
    if (self.session_replay_enabled != that.session_replay_enabled) return NO;
    if (self.has_session_replay_config != that.has_session_replay_config) return NO;
    if (self.session_replay_customRules != that.session_replay_customRules) return NO;
    if (self.session_replay_maskAllImages != that.session_replay_maskAllImages) return NO;
    if (self.session_replay_maskApplicationText != that.session_replay_maskApplicationText) return NO;
    if (self.session_replay_maskUserInputText != that.session_replay_maskUserInputText) return NO;
    if (self.session_replay_maskAllUserTouches != that.session_replay_maskAllUserTouches) return NO;


    return [self.data_token isEqual:that.data_token];
}

- (NSUInteger) hash
{
    NSUInteger result = self.collect_network_errors ? 1 : 0;
    result = 31 * result + self.application_token.hash;
    result = 31 * result + self.cross_process_id.hash;
    result = 31 * result + self.data_report_period;
    result = 31 * result + self.data_token.hash;
    result = 31 * result + self.error_limit;
    result = 31 * result + self.report_max_transaction_age;
    result = 31 * result + self.report_max_transaction_count;
    result = 31 * result + self.response_body_limit;
    result = 31 * result + (int)(self.server_timestamp ^ (self.server_timestamp >> 32));
    result = 31 * result + self.stack_trace_limit;
    result = 31 * result + self.activity_trace_max_size;
    result = 31 * result + self.activity_trace_max_send_attempts;
    result = 31 * result + (unsigned int)self.account_id;
    result = 31 * result + (unsigned int)self.application_id;
    result = 31 * result + self.encoding_key.hash;
    result = 31 * result + self.trusted_account_key.hash;

    result = 31 * result + self.entity_guid.hash;
    result = 31 * result + self.sampling_rate;
    result = 31 * result + self.log_reporting_level.hash;
    result = 31 * result + self.log_reporting_enabled;
    result = 31 * result + self.has_log_reporting_config;
    result = 31 * result + self.request_header_map.hash;


    // session replay

//    result = 31 * result + self.log_reporting_level.hash;
    result = 31 * result + self.session_replay_enabled;
    result = 31 * result + self.session_replay_sampling_rate;
    result = 31 * result + self.session_replay_mode.hash;

    return result;
}
@end

@implementation SessionReplayCustomMaskingRule

- (id) initWithDictionary:(NSDictionary*)dict {
    self = [super init];

    if (self) {

        self.identifier = [dict valueForKey:kNRMA_SESSION_REPLAY_CONFIG_IDENTIFIER_KEY];
        self.name = [dict valueForKey:kNRMA_SESSION_REPLAY_CONFIG_NAME_KEY];
        self.operatorName = [dict valueForKey:kNRMA_SESSION_REPLAY_CONFIG_OPERATOR_KEY];
        self.type = [dict valueForKey:kNRMA_SESSION_REPLAY_CONFIG_TYPE_KEY];

    }
    return self;
}

@end
