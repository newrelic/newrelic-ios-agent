//
// Created by Bryce Buchanan on 6/12/17.
//  Copyright © 2023 New Relic. All rights reserved.
//

#include "LongAttributes.hpp"

using namespace com::newrelic::mobile::fbs;
using namespace flatbuffers;
using namespace NewRelic::Hex::Report;

LongAttributes::LongAttributes() : Attributes() {}

flatbuffers::Offset<Vector<Offset<LongSessionAttribute>>>
LongAttributes::serialize(flatbuffers::FlatBufferBuilder& builder) const {
    std::vector<Offset<LongSessionAttribute>> attributesVector;

    for (auto kvp : get_attributes()) {
        auto builtKey = builder.CreateString(kvp.first);
        auto attributeBuilder = LongSessionAttributeBuilder(builder);
        attributeBuilder.add_name(builtKey);
        attributeBuilder.add_value(kvp.second);
        auto builtAttribute = attributeBuilder.Finish();
        attributesVector.push_back(builtAttribute);
    }
    return builder.CreateVector(attributesVector);
}
