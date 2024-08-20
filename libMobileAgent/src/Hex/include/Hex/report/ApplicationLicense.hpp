//
// Created by Bryce Buchanan on 6/13/17.
//  Copyright © 2023 New Relic. All rights reserved.
//

#ifndef LIBMOBILEAGENT_APPLICATIONLICENSE_HPP
#define LIBMOBILEAGENT_APPLICATIONLICENSE_HPP

#include <Hex/ios_generated.h>
#include <Hex/hex_generated.h>
#include <Hex/session-attributes_generated.h>
#include <Hex/jserror_generated.h>
#include <Hex/hex-agent-data_generated.h>

using namespace com::newrelic::mobile;
using namespace flatbuffers;
namespace NewRelic {
    namespace Hex {
        namespace Report {
            class ApplicationLicense {
            public:
                explicit ApplicationLicense(const char* licenseKey);

                Offset<fbs::ApplicationLicense> serialize(flatbuffers::FlatBufferBuilder& builder) const;

            private:
                std::string _licenseKey;
            };
        }
    }
}

#endif //LIBMOBILEAGENT_APPLICATIONLICENSE_HPP
