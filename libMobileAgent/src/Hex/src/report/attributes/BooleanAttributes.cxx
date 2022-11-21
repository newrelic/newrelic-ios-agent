//
// Created by Bryce Buchanan on 6/12/17.
//

#include "BooleanAttributes.hpp"

using namespace com::newrelic::mobile;
using namespace flatbuffers;
using namespace NewRelic::Hex::Report;

BooleanAttributes::BooleanAttributes() : Attributes() {}

Offset<Vector<Offset<fbs::BoolSessionAttribute>>>
BooleanAttributes::serialize(flatbuffers::FlatBufferBuilder& builder) const {
    std::vector<Offset<fbs::BoolSessionAttribute>> attributesVector;

    for (auto kvp : get_attributes()) {
        auto builtKey = builder.CreateString(kvp.first);
        auto attributeBuilder = fbs::BoolSessionAttributeBuilder(builder);
        attributeBuilder.add_name(builtKey);
        attributeBuilder.add_value(kvp.second);
        auto builtAttribute = attributeBuilder.Finish();
        attributesVector.push_back(builtAttribute);
    }
    return builder.CreateVector(attributesVector);
}
