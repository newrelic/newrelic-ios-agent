//
// Created by Bryce Buchanan on 6/12/17.
//

#include "Attributes.hpp"
#include "DoubleAttributes.hpp"


using namespace com::newrelic::mobile::fbs;
using namespace flatbuffers;
using namespace NewRelic::Hex::Report;
DoubleAttributes::DoubleAttributes() : Attributes() {}


flatbuffers::Offset<Vector<Offset<DoubleSessionAttribute>>>
DoubleAttributes::serialize(flatbuffers::FlatBufferBuilder& builder) const {
    std::vector<Offset<DoubleSessionAttribute>> attributesVector;
    for (auto kvp : get_attributes()) {
        auto builtKey = builder.CreateString(kvp.first);
        auto attributeBuilder = DoubleSessionAttributeBuilder(builder);
        attributeBuilder.add_name(builtKey);
        attributeBuilder.add_value(kvp.second);
        auto builtAttribute = attributeBuilder.Finish();
        attributesVector.push_back(builtAttribute);
    }
    return builder.CreateVector(attributesVector);
}
