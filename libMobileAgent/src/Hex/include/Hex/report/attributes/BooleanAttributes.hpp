//
// Created by Bryce Buchanan on 6/12/17.
//  Copyright © 2023 New Relic. All rights reserved.
//

#ifndef LIBMOBILEAGENT_BOOL_HPP
#define LIBMOBILEAGENT_BOOL_HPP

#include <Hex/session-attributes_generated.h>
#include <Hex/Attributes.hpp>
#include <Hex/jserror_generated.h>

using namespace com::newrelic::mobile;
using namespace flatbuffers;
namespace NewRelic {
    namespace Hex {
        namespace Report {
            class BooleanAttributes : public Attributes<bool> {
            public:
                BooleanAttributes();

                Offset<Vector<Offset<fbs::BoolSessionAttribute>>>
                serialize(flatbuffers::FlatBufferBuilder& builder) const;
            };
        }
    }
}


#endif //LIBMOBILEAGENT_BOOL_HPP
