//
//  NRLogger.m
//  NewRelicAgent
//
//  Created by Jonathan Karon on 10/9/12.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import "NRLogger.h"
#import "NewRelicInternalUtils.h"
#import "NRMAJSON.h"
#import "NewRelicAgentInternal.h"
#import "NRMAHarvestController.h"
#import "NRMAHarvesterConfiguration.h"

NRLogger *_nr_logger = nil;

@interface NRLogger()
- (void)addLogMessage:(NSDictionary *)message;
- (void)setLogLevels:(unsigned int)levels;
- (void)setLogTargets:(unsigned int)targets;
- (void)clearLog;
@end

@implementation NRLogger

+ (NRLogger *)logger {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _nr_logger = [[NRLogger alloc] init];
    });
    return _nr_logger;
}

+ (void)log:(unsigned int)level
     inFile:(NSString *)file
     atLine:(unsigned int)line
   inMethod:(NSString *)method
withMessage:(NSString *)message {

    NRLogger *logger = [NRLogger logger];
    BOOL shouldLog = NO;
    @synchronized(logger) {
        shouldLog = (logger->logLevels & level) != 0;
    }

    if (shouldLog) {
        [logger addLogMessage:[NSDictionary dictionaryWithObjectsAndKeys:
                               [NSNumber numberWithUnsignedInt:level], NRLogMessageLevelKey,
                               file, NRLogMessageFileKey,
                               [NSNumber numberWithUnsignedInt:line], NRLogMessageLineNumberKey,
                               method, NRLogMessageMethodKey,
                               [NSNumber numberWithLongLong: (long long)([[NSDate date] timeIntervalSince1970] * 1000.0)], NRLogMessageTimestampKey,
                               message, NRLogMessageMessageKey,
                               nil]];
    }
}

+ (NRLogLevels) logLevels {
    return [[NRLogger logger] logLevels];
}

+ (void)setLogLevels:(unsigned int)levels {
    [[NRLogger logger] setLogLevels:levels];
}

+ (void)setLogTargets:(unsigned int)targets {
    [[NRLogger logger] setLogTargets:targets];
}

+ (void)setLogURL:(NSString*) url {
    [[NRLogger logger] setLogURL:url];
}

+ (NSString *)logFilePath {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
    NSString *basePath = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
    if (basePath) {
        return [[basePath stringByAppendingPathComponent:@"newrelic"] stringByAppendingPathComponent:@"log.json"];
    }
    NSLog(@"NewRelic: No NSDocumentDirectory found, file logging will not be available.");
    return nil;
}

+ (void)clearLog {
    [[NRLogger logger] clearLog];
}

+ (void)upload {
    [[NRLogger logger] upload];
}

#pragma mark -- internal

- (id)init {
    self = [super init];
    if (self) {
        self->logLevels = NRLogLevelError | NRLogLevelWarning;
        self->logTargets = NRLogTargetConsole;
        self->logFile = nil;
    }
    return self;
}

- (void)dealloc {
    @synchronized(self) {
        if (self->logFile) {
            [self->logFile closeFile];
            self->logFile = nil;
        }
    }
}

- (void)addLogMessage:(NSDictionary *)message {
    // The static method checks the log level before we get here.
    @synchronized(self) {
        if (self->logTargets & NRLogTargetConsole) {
            NSLog(@"NewRelic(%@,%p):\t%@:%@\t%@\n\t%@",
                  [NewRelicInternalUtils agentVersion],
                  [NSThread currentThread],
                  [message objectForKey:NRLogMessageFileKey],
                  [message objectForKey:NRLogMessageLineNumberKey],
                  [message objectForKey:NRLogMessageMethodKey],
                  [message objectForKey:NRLogMessageMessageKey]);
        }
        if (self->logTargets & NRLogTargetFile) {
            NSData *json = [self jsonDictionary:message];
            if (json) {
                if ([self->logFile offsetInFile]) {
                    [self->logFile writeData:[NSData dataWithBytes:"," length:1]];
                }
                [self->logFile writeData:json];
            }
        }
    }
}

- (NSData*) jsonDictionary:(NSDictionary*)message {
    NSString* nrSessiondId = [[[NewRelicAgentInternal sharedInstance] currentSessionId] copy];
    NRMAHarvesterConfiguration *configuration = [NRMAHarvestController configuration];
    NSString* nrAppId = [NSString stringWithFormat:@"%lld", configuration.application_id];
    NSString* json = [NSString stringWithFormat:@"{ \n  \"%@\":\"%@\",\n  \"%@\" : \"%@\",\n  \"%@\" : \"%@\",\n  \"%@\" : \"%@\",\n  \"%@\" : \"%@\",\n  \"%@\" : \"%@\"\n,\n  \"%@\" : \"%@\"\n, \n  \"%@\" : \"%@\"\n}",
                      NRLogMessageLevelKey, [message objectForKey:NRLogMessageLevelKey],
                      NRLogMessageFileKey, [[message objectForKey:NRLogMessageFileKey]stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""],
                      NRLogMessageLineNumberKey,[message objectForKey:NRLogMessageLineNumberKey],
                      NRLogMessageMethodKey,[[message objectForKey:NRLogMessageMethodKey]stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""],
                      NRLogMessageTimestampKey,[message objectForKey:NRLogMessageTimestampKey],
                      NRLogMessageMessageKey,[[message objectForKey:NRLogMessageMessageKey]stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""],
                      @"sessionId", nrSessiondId,
                      @"appId", nrAppId];

    return [json dataUsingEncoding:NSUTF8StringEncoding];
}

- (void)setLogLevels:(unsigned int)levels {
    @synchronized(self) {
        unsigned int l = 0;
        switch (levels) {
            case NRLogLevelError:
                l = NRLogLevelError; break;
            case NRLogLevelWarning:
                l = NRLogLevelError | NRLogLevelWarning; break;
            case NRLogLevelInfo:
                l = NRLogLevelError | NRLogLevelWarning | NRLogLevelInfo; break;
            case NRLogLevelVerbose:
                l = NRLogLevelError | NRLogLevelWarning | NRLogLevelInfo | NRLogLevelVerbose; break;
            case NRLogLevelAudit:
                l = NRLogLevelError | NRLogLevelWarning | NRLogLevelInfo | NRLogLevelVerbose | NRLogLevelAudit ; break;
            default:
                l = levels; break;
        }
        self->logLevels = l;
    }
}

- (NRLogLevels) logLevels {
    return self->logLevels;
}

- (void)setLogTargets:(unsigned int)targets {
    NSString *fileOpenError = nil;

    @synchronized(self) {
        self->logTargets = targets;
        if (targets & NRLogTargetFile) {
            if (! self->logFile) {
                NSString *path = [NRLogger logFilePath];
                NSString *parent = [path stringByDeletingLastPathComponent];
                NSError *err;
                BOOL success = [[NSFileManager defaultManager] createDirectoryAtPath:parent
                                                         withIntermediateDirectories:YES
                                                                          attributes:nil
                                                                               error:&err];
                if (! success) {
                    fileOpenError = [NSString stringWithFormat:@"Cannot create log file directory '%@': %@", parent, [err description]];
                }
                else {
                    if (! [[NSFileManager defaultManager] fileExistsAtPath:path]) {
                        success = [[NSFileManager defaultManager] createFileAtPath:path
                                                                          contents:[[NSData alloc] init]
                                                                        attributes:nil];
                        if (! success) {
                            fileOpenError = [NSString stringWithFormat:@"Cannot create log file '%@'", path];
                        }
                    }
                    if (success) {
                        self->logFile = [NSFileHandle fileHandleForUpdatingAtPath:path];
                        [self->logFile seekToEndOfFile];
                        if (! self->logFile) {
                            success = NO;
                            fileOpenError = [NSString stringWithFormat:@"Cannot write log file '%@'", path];
                        }
                    }
                }

                if (! success) {
                    self->logTargets &= ~NRLogTargetFile;
                }
            }
        }
        else {
            if (self->logFile) {
                [self->logFile closeFile];
                self->logFile = nil;
            }
        }
    }

    if (fileOpenError) {
        if (self->logTargets && self->logLevels) {
            NRLOG_ERROR(@"%@", fileOpenError);
        }
        else {
            NSLog(@"NewRelic: error opening log file %@", fileOpenError);
        }
    }
}

- (void)clearLog {
    @synchronized(self) {
        if (self->logFile) {
            // Close the log file if it's open.
            [self->logFile closeFile];
            self->logFile = nil;

            // Truncate the log file on disk.
            NSString *path = [NRLogger logFilePath];
            NSError *err = nil;
            if (! [[NSFileManager defaultManager] removeItemAtPath:path error:&err]) {
                NSLog(@"NewRelic: Unable to truncate log file at '%@'", path);
            }

            // Calling setLogTargets: will re-open the file safely.
            // Note: @synchronized is re-entrant, so we don't need to worry about lock contention.
            [self setLogTargets:self->logTargets];
        }
    }
}

- (void)setLogURL:(NSString*)url {
    self->logURL = url;
}

- (void)upload {
    @synchronized (self) {
        if (self->logFile) {
            // 
            if (!self->logURL) {
                NRLOG_VERBOSE(@"Set Logging URL to upload logs to New Relic using the Logs API.");
                return;
            }

            NSString *path = [NRLogger logFilePath];
            NSData* logData = [NSData dataWithContentsOfFile:path];

            NSString* logMessagesJson = [NSString stringWithFormat:@"[ %@ ]", [[NSString alloc] initWithData:logData encoding:NSUTF8StringEncoding]];
            NSData* formattedData = [logMessagesJson dataUsingEncoding:NSUTF8StringEncoding];
            NSURLSession *session = [NSURLSession sessionWithConfiguration:NSURLSession.sharedSession.configuration];
            NSMutableURLRequest* req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:self->logURL]];

            req.HTTPMethod = @"POST";

            NSURLSessionUploadTask *uploadTask = [session uploadTaskWithRequest:req fromData:formattedData completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {

                BOOL errorCode = false;
                if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
                    NSInteger responseCode = ((NSHTTPURLResponse*)response).statusCode;
                    errorCode = responseCode >= 300;
                }
                if (!error && !errorCode) {
                    NRLOG_VERBOSE(@"Logs uploaded successfully.");
                }
                else if (errorCode) {
                    NRLOG_ERROR(@"Logs failed to upload. response: %@", response);

                }
                else {
                    NRLOG_ERROR(@"Logs failed to upload. error: %@", error);
                }
            }];

            [uploadTask resume];
            [self clearLog];

        }
    }
}

@end

