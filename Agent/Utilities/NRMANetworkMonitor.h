//
//  NRMANetworkMonitor.h
//  Agent
//
//  Created by Mike Bruin on 10/3/23.
//  Copyright © 2023 New Relic. All rights reserved.
//

@interface NRMANetworkMonitor : NSObject
- (instancetype)init API_AVAILABLE(ios(12.0), tvos(12.0));

- (void) startNetworkMonitoring API_AVAILABLE(ios(12.0), tvos(12.0));
- (void) stopNetworkMonitoring API_AVAILABLE(ios(12.0), tvos(12.0));
- (NSString*) getConnectionType;

@end
