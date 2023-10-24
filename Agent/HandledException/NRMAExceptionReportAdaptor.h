//
// Created by Bryce Buchanan on 7/6/17.
// Copyright © 2023 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>
#include <Hex/HexReport.hpp>

@interface NRMAExceptionReportAdaptor : NSObject
{
    std::shared_ptr<NewRelic::Hex::Report::HexReport> _report;
}

- (instancetype) initWithReport:(std::shared_ptr<NewRelic::Hex::Report::HexReport>) report;

- (void) addAttributes:(NSDictionary*)attributes;
- (void) addAttributesNoValidation:(NSDictionary*)attributes;

- (std::shared_ptr<NewRelic::Hex::Report::HexReport>) report;

@end
