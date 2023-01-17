//
//  NRMAThread.h
//  NewRelicAgent
//
//  Created by Bryce Buchanan on 9/9/13.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NRMAThread : NSObject
+ (BOOL) instrumentNSThread;
+ (BOOL) deinstrumentNSThread;
@end

