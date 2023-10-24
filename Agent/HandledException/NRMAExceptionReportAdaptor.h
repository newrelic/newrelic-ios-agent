//
// Created by Bryce Buchanan on 7/6/17.
// Copyright © 2023 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>
#include <Hex/HexReport.hpp>
#import "NRMAAnalytics.h"

@interface NRMAExceptionReportAdaptor : NSObject
{
    std::shared_ptr<NewRelic::Hex::Report::HexReport> _report;
    id<AttributeValidatorProtocol> _attributeValidator;
}

- (instancetype) initWithReport:(std::shared_ptr<NewRelic::Hex::Report::HexReport>) report attributeValidator:(id<AttributeValidatorProtocol>) attributeValidator;

- (void) addAttributes:(NSDictionary*)attributes;
- (void) addAttributesNewValidation:(NSDictionary*)attributes;

- (std::shared_ptr<NewRelic::Hex::Report::HexReport>) report;

@end
