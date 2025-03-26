//
//  SupportabilityMetrics.swift
//  Agent_iOS
//
//  Created by Steve Malsam on 3/25/25.
//  Copyright © 2025 New Relic. All rights reserved.
//

import Foundation
import NewRelic.Private

class SupportabilityMetrics {
//    [NRMATaskQueue queue:[[NRMAMetric alloc] initWithName:kNRSupportabilityDistributedTracing@"/Create/Exception"
//                       value:@1
//                   scope:@""]];
    
    func createExceptionMetric() {
        NRMATaskQueue.queue(NRMAMetric(name: "A name", value: 1, scope: ""))
    }
    
}
