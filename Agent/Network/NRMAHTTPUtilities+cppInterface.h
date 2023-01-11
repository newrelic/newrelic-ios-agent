//
//  NRMAHTTPUtilities+cppInterface.h
//  NewRelicAgent
//
//  Created by Bryce Buchanan on 8/28/14.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import <Connectivity/Payload.hpp>
#import "NRMAHTTPUtilities.h"

@interface NRMAHTTPUtilities (cppInterface)
+ (std::unique_ptr<NewRelic::Connectivity::Payload>) retrievePayload:(NSURLRequest*)request;
@end
