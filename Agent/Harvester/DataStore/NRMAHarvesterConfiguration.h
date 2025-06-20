//
//  NRHavesterConfiguration.h
//  NewRelicAgent
//
//  Created by Bryce Buchanan on 8/27/13.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NRMADataToken.h"
#import "NRMATraceConfigurations.h"
#import "NRConstants.h"

#define kNRMA_LICENSE_KEY @"application_token"
#define kNRMA_COLLECT_NETWORK_ERRORS @"collect_network_errors"
#define kNRMA_CROSS_PROCESS_ID @"cross_process_id"
#define kNRMA_DATA_REPORT_PERIOD @"data_report_period"
#define kNRMA_DATA_TOKEN @"data_token"
#define kNRMA_ERROR_LIMIT @"error_limit"
#define kNRMA_REPORT_MAX_TRANSACTION_AGE @"report_max_transaction_age"
#define kNRMA_REPORT_MAX_TRANSACTION_COUNT @"report_max_transaction_count"
#define kNRMA_RESPONSE_BODY_LIMIT @"response_body_limit"
#define kNRMA_SERVER_TIMESTAMP @"server_timestamp"
#define kNRMA_STACK_TRACE_LIMIT @"stack_trace_limit"
#define kNRMA_AT_CAPTURE @"at_capture"
#define kNRMA_AT_MAX_SIZE @"activity_trace_max_size"
#define kNRMA_AT_MAX_SEND_ATTEMPTS @"activity_trace_max_send_attempts"
#define KNRMA_AT_MIN_UTILIZATION @"activity_trace_min_utilization"
#define kNRMA_ENCODING_KEY @"encoding_key"
#define kNRMA_ACCOUNT_ID @"account_id"
#define kNMRA_APPLICATION_ID @"application_id"
#define kNRMA_TRUSTED_ACCOUNT_KEY @"trusted_account_key"
#define kNRMA_ENTITY_GUID_KEY @"entity_guid"
#define kNRMA_CONFIG_KEY @"configuration"

// Session Replay Configuration Keys
#define kNRMA_SESSION_REPLAY_CONFIG_KEY @"mobile_session_replay"

#define kNRMA_SESSION_REPLAY_CONFIG_IDENTIFIER_KEY @"idemtifier"
#define kNRMA_SESSION_REPLAY_CONFIG_NAME_KEY @"name"
#define kNRMA_SESSION_REPLAY_CONFIG_OPERATOR_KEY @"name"
#define kNRMA_SESSION_REPLAY_CONFIG_TYPE_KEY @"type"

#define kNRMA_SESSION_REPLAY_CONFIG_ENABLED_KEY @"enabled"
#define kNRMA_SESSION_REPLAY_CONFIG_SAMPLERATE_KEY @"samplingRate"
#define kNRMA_SESSION_REPLAY_CONFIG_ERRORRATE_KEY @"errorSamplingRate"
#define kNRMA_SESSION_REPLAY_CONFIG_MODE_KEY @"mode"
#define kNRMA_SESSION_REPLAY_CONFIG_maskApplicationText_KEY @"maskApplicationText"
#define kNRMA_SESSION_REPLAY_CONFIG_maskUserInputText_KEY @"maskUserInputText"
#define kNRMA_SESSION_REPLAY_CONFIG_maskAllUserTouches_KEY @"maskAllUserTouches"
#define kNRMA_SESSION_REPLAY_CONFIG_maskAllImages_KEY @"maskAllImages"
#define kNRMA_SESSION_REPLAY_CONFIG_customMaskingRules_KEY @"customMaskingRules"

// End Session Replay Configuration Keys

#define kNRMA_LOG_REPORTING_KEY @"logs"
#define kNRMA_LOG_REPORTING_SAMPLE_RATE_KEY @"sampling_rate"
#define KNRMA_REQUEST_HEADER_MAP_KEY @"request_headers_map"
#define kNRMA_LOG_REPORTING_ENABLED_KEY @"enabled"
#define kNRMA_LOG_REPORTING_LEVEL_KEY @"level"
#define kNRMA_LOG_REPORTING_LEVEL_DEFAULT @"WARN"

#define NRMA_DEFAULT_COLLECT_NETWORK_ERRORS YES  // boolean
#define NRMA_DEFAULT_REPORT_PERIOD 60            // seconds
#define NRMA_DEFAULT_ERROR_LIMIT 50              // errors
#define NRMA_DEFAULT_RESPONSE_BODY_LIMIT 2048    // bytes
#define NRMA_DEFAULT_STACK_TRACE_LIMIT 100       // stack frames
#define NRMA_DEFAULT_MAX_TRANSACTION_AGE 600     // seconds
#define NRMA_DEFAULT_MAX_TRANSACTION_COUNT 1000  // transactions
#define NRMA_DEFAULT_ACTIVITY_TRACE_MAX_SIZE 65535 // bytes
#define NRMA_DEFAULT_ACTIVITY_TRACE_MAX_SEND_ATTEMPTS 2 // max times to attempt to send a given AT
#define NRMA_DEFAULT_ACTIVITY_TRACE_MIN_UTILIZATION .3  // the minimum utilization of a trace, below this cut off are not reported
@interface NRMAHarvesterConfiguration : NSObject
@property(nonatomic,strong) NSString* application_token;
@property(nonatomic,assign) BOOL      collect_network_errors;
@property(nonatomic,strong) NSString* cross_process_id;
@property(nonatomic,assign) int       data_report_period;
@property(nonatomic,strong) NRMADataToken*  data_token;
@property(nonatomic,assign) int       error_limit;
@property(nonatomic,assign) int       report_max_transaction_age;
@property(nonatomic,assign) int       report_max_transaction_count;
@property(nonatomic,assign) int       response_body_limit;
@property(nonatomic,assign) long long server_timestamp;
@property(nonatomic,assign) int       stack_trace_limit;
@property(nonatomic,assign) int       activity_trace_max_size;
@property(nonatomic,assign) int       activity_trace_max_send_attempts;
@property(nonatomic,strong) NRMATraceConfigurations*  at_capture;
@property(nonatomic,assign) double    activity_trace_min_utilization;
@property(nonatomic,assign) NSString* encoding_key;
@property(nonatomic,assign) long long account_id;
@property(nonatomic,assign) long long application_id;
@property(nonatomic,strong) NSString* trusted_account_key;
@property(nonatomic,strong) NSString* entity_guid;
@property(nonatomic,assign) BOOL      log_reporting_enabled;
@property(nonatomic,assign) double    sampling_rate;
@property(nonatomic,assign) BOOL      has_log_reporting_config;
@property(nonatomic,assign) NSDictionary* request_header_map;


// CAN BE
// NONE < ERROR < WARN < INFO < DEBUG < AUDIT < VERBOSE
@property(nonatomic,assign) NSString* log_reporting_level;

// Session Replay Configuration

@property(nonatomic,assign) BOOL      has_session_replay_config;
@property(nonatomic,assign) BOOL      session_replay_enabled;
@property(nonatomic,assign) double    session_replay_sampling_rate;
@property(nonatomic,assign) double    session_replay_error_sampling_rate;
@property(nonatomic,assign) NSString*    session_replay_mode;

@property(nonatomic,assign) BOOL      session_replay_maskApplicationText;
@property(nonatomic,assign) BOOL      session_replay_maskUserInputText;
@property(nonatomic,assign) BOOL      session_replay_maskAllUserTouches;
@property(nonatomic,assign) BOOL     session_replay_maskAllImages;

@property(nonatomic,assign) enum SessionReplayTextMaskingStrategy     session_replay_textMaskingStrategy;

// Lists for tracking masked elements in SessionReplay
@property (nonatomic, strong) NSMutableSet *session_replay_maskedAccessibilityIdentifiers;
@property (nonatomic, strong) NSMutableSet *session_replay_maskedClassNames;


// Lists for tracking unmasked elements in SessionReplay
@property (nonatomic, strong) NSMutableSet *session_replay_unmaskedAccessibilityIdentifiers;
@property (nonatomic, strong) NSMutableSet *session_replay_unmaskedClassNames;


@property (nonatomic, strong) NSMutableSet *session_replay_customRules;

// End Session Replay Configuration

+ (id) defaultHarvesterConfiguration;
- (BOOL) isValid;
- (BOOL) isEqual:(id)object;
- (NSUInteger) hash;
- (id) initWithDictionary:(NSDictionary*)dict;
- (NSDictionary*) asDictionary;

@end


@interface SessionReplayCustomMaskingRule : NSObject
@property(nonatomic,assign) NSString*    identifier;
@property(nonatomic,assign) NSString*    name;
@property(nonatomic,assign) NSString*    operatorName;
@property(nonatomic,assign) NSString*    type;
- (id) initWithDictionary:(NSDictionary*)dict;


@end

