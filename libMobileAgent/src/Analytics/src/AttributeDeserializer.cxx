//
// Created by Bryce Buchanan on 2/5/16.
//  Copyright © 2023 New Relic. All rights reserved.
//


#include "Analytics/AttributeDeserializer.hpp"
#include "AnalyticEvent.hpp"
namespace NewRelic {
    std::shared_ptr<AttributeBase> AttributeDeserializer::deserializeAttributes(std::istream& is) {

        std::string attributeName;

        attributeName =  readStreamToDelimiter(is, AnalyticEvent::_delimiter).str();

        is.ignore(std::numeric_limits<std::streamsize>::max(), AnalyticEvent::_delimiter);

        if (attributeName.length() == 0) return nullptr;

        auto baseValue = Value::createValue(is); //throws runtime_error if 'is' is bad

        auto attribute = std::make_shared<AttributeBase>(AttributeBase(attributeName,baseValue));

        is.ignore(std::numeric_limits<std::streamsize>::max(), AnalyticEvent::_delimiter);

        return attribute;
    }
}

