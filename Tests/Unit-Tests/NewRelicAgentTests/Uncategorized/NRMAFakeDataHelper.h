//
//  NRMAFakeDataHelper.h
//  Agent
//
//  Created by Mike Bruin on 12/1/22.
//  Copyright © 2022 New Relic. All rights reserved.
//

@interface NRMAFakeDataHelper : NSObject
+(BOOL) makeFakeCrashReport:(NSUInteger) size;;
+(NSString *) makeStringOfSizeInBytes:(NSUInteger) size;
+(NSData*) makeDataDictionary:(NSUInteger) size;

@end
