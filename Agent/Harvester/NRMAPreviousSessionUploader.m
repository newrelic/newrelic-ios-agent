//
//  NRMAPreviousSessionUploader.m
//  NewRelicAgent
//
//  Copyright © 2024 New Relic. All rights reserved.
//

#import "NRMAPreviousSessionUploader.h"
#import "NRMAPreviousSessionHarvestable.h"
#import "NRMAAgentConfiguration.h"
#import "NRMAConnectInformation.h"
#import "NRMADeviceInformation.h"
#import "NRLogger.h"

// Hard cap: a previous-session batch whose store file hasn't been touched in
// longer than this is never uploaded. Checked against the file's modification date.
static const NSTimeInterval kNRMAPreviousSessionEventRetentionMs = 7.0 * 24 * 60 * 60 * 1000.0;

@implementation NRMAPreviousSessionUploader {
    NSString* _attributeJSON;
    NSString* _eventJSON;
    NSDate* _fileModificationDate;
    BOOL _captured;   // YES once the previous session's data has been read/handed to us.
    BOOL _didUpload;  // YES once we have made a definitive attempt (sent, or confirmed nothing to send).
}

+ (instancetype) sharedInstance {
    static NRMAPreviousSessionUploader* sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[NRMAPreviousSessionUploader alloc] init];
    });
    return sharedInstance;
}

- (void) setLastSessionAttributeJSON:(NSString*)attributeJSON
                           eventJSON:(NSString*)eventJSON
                fileModificationDate:(NSDate*)fileModificationDate {
    @synchronized (self) {
        _attributeJSON = [attributeJSON copy];
        _eventJSON = [eventJSON copy];
        _fileModificationDate = fileModificationDate;
        _captured = YES;
    }
}

- (void) uploadWithConnection:(NRMAHarvesterConnection*)connection
                    dataToken:(NRMADataToken*)dataToken {
    NSString* attributeJSON;
    NSString* eventJSON;
    NSDate* fileModificationDate;
    @synchronized (self) {
        if (_didUpload) {
            return;
        }
        // The previous session's data is captured asynchronously at launch and
        // may not have arrived yet by the first connect. Do NOT latch the guard
        // until it has — otherwise we permanently skip when the harvest wins the
        // race. Returning without latching lets the next harvest retry.
        if (!_captured) {
            NRLOG_AGENT_VERBOSE(@"Previous session analytics not captured yet; will retry next harvest.");
            return;
        }
        // We have the data (possibly empty). This is our one definitive attempt.
        _didUpload = YES;
        attributeJSON = _attributeJSON;
        eventJSON = _eventJSON;
        fileModificationDate = _fileModificationDate;
    }

    if (connection == nil) {
        NRLOG_AGENT_VERBOSE(@"Skipping previous session upload: no connection.");
        return;
    }

    if ([self isOlderThanRetentionWindow:fileModificationDate]) {
        NRLOG_AGENT_VERBOSE(@"Previous session's persisted analytics are older than the 7-day retention window; skipping upload.");
        return;
    }

    NSArray* events = [self eventsFromJSON:eventJSON];
    NSDictionary* attributes = [self attributesFromJSON:attributeJSON];

    // Nothing meaningful to send.
    if (events.count == 0 || attributes.count == 0) {
        NRLOG_AGENT_VERBOSE(@"Not sending previous session analytics on launch: %lu event(s), %lu attribute(s).",(unsigned long)events.count, (unsigned long)attributes.count);
        return;
    }

    NRMADeviceInformation* deviceInformation = [NRMAAgentConfiguration connectionInformation].deviceInformation;

    NRMAPreviousSessionHarvestable* harvestable = [[NRMAPreviousSessionHarvestable alloc] initWithDataToken:dataToken
                                                                                          deviceInformation:deviceInformation
                                                                                                 attributes:attributes
                                                                                                     events:events];

    NRLOG_AGENT_VERBOSE(@"Sending previous session analytics on launch: %lu event(s), %lu attribute(s).",
                        (unsigned long)events.count, (unsigned long)attributes.count);

    @try {
        [connection sendData:harvestable];
    } @catch (NSException* exception) {
        NRLOG_AGENT_ERROR(@"Failed to send previous session analytics: %@", exception.reason);
    }
}

#pragma mark - Helpers

// Nil (unknown mtime) fails open -- we don't skip data we can't confidently age.
- (BOOL) isOlderThanRetentionWindow:(NSDate*)fileModificationDate {
    if (fileModificationDate == nil) {
        return NO;
    }
    return [[NSDate date] timeIntervalSinceDate:fileModificationDate] * 1000.0 > kNRMAPreviousSessionEventRetentionMs;
}

- (NSArray*) eventsFromJSON:(NSString*)eventJSON {
    if (eventJSON.length == 0) {
        return @[];
    }
    NSError* error = nil;
    id parsed = [NSJSONSerialization JSONObjectWithData:[eventJSON dataUsingEncoding:NSUTF8StringEncoding]
                                                options:0
                                                  error:&error];
    if (error != nil || ![parsed isKindOfClass:[NSArray class]]) {
        NRLOG_AGENT_VERBOSE(@"Failed to parse previous session events: %@", error.localizedDescription);
        return @[];
    }
    return (NSArray*)parsed;
}

- (NSDictionary*) attributesFromJSON:(NSString*)attributeJSON {
    if (attributeJSON.length == 0) {
        return @{};
    }
    NSError* error = nil;
    id parsed = [NSJSONSerialization JSONObjectWithData:[attributeJSON dataUsingEncoding:NSUTF8StringEncoding]
                                                options:0
                                                  error:&error];
    if (error != nil || ![parsed isKindOfClass:[NSDictionary class]]) {
        NRLOG_AGENT_VERBOSE(@"Failed to parse previous session attributes: %@", error.localizedDescription);
        return @{};
    }
    return (NSDictionary*)parsed;
}

@end
