//
// Created by Bryce Buchanan on 6/12/17.
//

#include "StringAttributes.hpp"

using namespace com::newrelic::mobile::fbs;
using namespace flatbuffers;
using namespace NewRelic::Hex::Report;

StringAttributes::StringAttributes() : Attributes() {
}

flatbuffers::Offset<Vector<Offset<StringSessionAttribute>>>
StringAttributes::serialize(flatbuffers::FlatBufferBuilder& builder) const {
    std::vector<Offset<StringSessionAttribute>> attributesVector;

    for (auto kvp : get_attributes()) {
        auto builtKey = builder.CreateString(kvp.first);
        auto builtValue = builder.CreateString(kvp.second);
        auto attributeBuilder = StringSessionAttributeBuilder(builder);
        attributeBuilder.add_name(builtKey);
        attributeBuilder.add_value(builtValue);
        auto builtAttribute = attributeBuilder.Finish();
        attributesVector.push_back(builtAttribute);
    }
    return builder.CreateVector(attributesVector);
}
