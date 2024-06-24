//
//  NRMAHarvesterConnection.h
//  NewRelicAgent
//
//  Copyright © 2023 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NRMAConnectInformation.h"
#import "NRMAHarvestResponse.h"
#import "NRLogger.h"
#import "NRMAJSON.h"
#import "NRMAConnection.h"
#import "NRMAOfflineStorage.h"

#define kCOLLECTOR_CONNECT_URI         @"/mobile/v5/connect"
#define kCOLLECTOR_DATA_URL            @"/mobile/v3/data"
#define kAPPLICATION_TOKEN_HEADER      @"X-App-License-Key"
#define kCONNECT_TIME_HEADER           @"X-NewRelic-Connect-Time"

@interface NRMAHarvesterConnection : NRMAConnection
@property(strong) NSString*             collectorHost;
@property(strong) NSString*             crossProcessID;
@property(assign) long long             serverTimestamp;
@property(strong) NSDictionary* requestHeadersMap;
@property(strong) NRMAConnectInformation* connectionInformation;
@property(strong) NSURLSession* harvestSession;
@property(strong) NRMAOfflineStorage* offlineStorage;

- (id) init;
- (NSURLRequest*) createPostWithURI:(NSString*)uri message:(NSString*)message;
- (NRMAHarvestResponse*) send:(NSURLRequest*)post;
- (NRMAHarvestResponse*) sendConnect;
- (NRMAHarvestResponse*) sendData:(NRMAHarvestable*)harvestable;
- (NSURLRequest*) createConnectPost:(NSString*)message;
- (NSURLRequest*) createDataPost:(NSString*)message;
- (NSArray<NSData *> *) getOfflineData;
- (void) sendOfflineStorage;
- (void) setMaxOfflineStorageSize:(NSUInteger) size;
@end
