//
// Created by Bryce Buchanan on 6/12/17.
//  Copyright © 2023 New Relic. All rights reserved.
//

#ifndef LIBMOBILEAGENT_DOUBLEATTRIBUTES_HPP
#define LIBMOBILEAGENT_DOUBLEATTRIBUTES_HPP


#include <Hex/session-attributes_generated.h>
#include <Hex/Attributes.hpp>
#include <Hex/BooleanAttributes.hpp>


using namespace com::newrelic::mobile::fbs;
using namespace flatbuffers;

namespace NewRelic {
    namespace Hex {
        namespace Report {
            class DoubleAttributes : public Attributes<double> {

            public:
                DoubleAttributes();

                flatbuffers::Offset<Vector<Offset<DoubleSessionAttribute>>>
                serialize(flatbuffers::FlatBufferBuilder& builder) const;
            };

        }
    }
}


#endif //LIBMOBILEAGENT_DOUBLEATTRIBUTES_HPP
