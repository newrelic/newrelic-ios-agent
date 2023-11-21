//
//  NRMAOfflineStorage.h
//  Agent
//
//  Created by Mike Bruin on 11/17/23.
//  Copyright © 2023 New Relic. All rights reserved.
//

@interface NRMAOfflineStorage : NSObject


- (id)initWithEndpoint:(NSString*) name;
- (BOOL)persistDataToDisk:(NSData*) data;
- (NSArray<NSData *> *) getAllOfflineData;

@end
