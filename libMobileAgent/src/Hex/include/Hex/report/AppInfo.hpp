//
// Created by Bryce Buchanan on 6/12/17.
//  Copyright © 2023 New Relic. All rights reserved.
//

#ifndef LIBMOBILEAGENT_APPINFO_HPP
#define LIBMOBILEAGENT_APPINFO_HPP


#include <Hex/ios_generated.h>
#include <Hex/hex_generated.h>
#include <Hex/session-attributes_generated.h>
#include <Hex/hex-agent-data_generated.h>
#include <Hex/ApplicationLicense.hpp>
#include <Hex/jserror_generated.h>

using namespace com::newrelic::mobile;
using namespace flatbuffers;

namespace NewRelic {
    namespace Hex {
        namespace Report {
            class AppInfo {
            public:
                AppInfo(ApplicationLicense* appLicense,
                        fbs::Platform platform);

                Offset<fbs::ApplicationInfo> serialize(flatbuffers::FlatBufferBuilder& builder) const;

            private:
                ApplicationLicense* _appLicense;
                fbs::Platform _platform;
            };
        }
    }
}


#endif //LIBMOBILEAGENT_APPINFO_HPP
