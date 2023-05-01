//
// Created by Bryce Buchanan on 6/12/17.
//  Copyright © 2023 New Relic. All rights reserved.
//

#ifndef LIBMOBILEAGENT_LONGATTRIBUTES_HPP
#define LIBMOBILEAGENT_LONGATTRIBUTES_HPP


#include <Hex/Attributes.hpp>
#include <Hex/session-attributes_generated.h>

using namespace com::newrelic::mobile::fbs;
using namespace flatbuffers;
namespace NewRelic {
    namespace Hex {
        namespace Report {
            class LongAttributes : public Attributes<long> {

            public:
                LongAttributes();

                flatbuffers::Offset<Vector<Offset<LongSessionAttribute>>>
                serialize(flatbuffers::FlatBufferBuilder&) const;


            };
        }
    }
}

#endif //LIBMOBILEAGENT_LONGATTRIBUTES_HPP
