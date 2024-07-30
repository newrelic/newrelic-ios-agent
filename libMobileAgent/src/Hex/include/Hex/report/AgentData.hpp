//
// Created by Bryce Buchanan on 6/12/17.
//  Copyright © 2023 New Relic. All rights reserved.
//

#ifndef LIBMOBILEAGENT_AGENTDATA_HPP
#define LIBMOBILEAGENT_AGENTDATA_HPP


#include <Hex/StringAttributes.hpp>
#include <Hex/BooleanAttributes.hpp>
#include <Hex/DoubleAttributes.hpp>
#include <Hex/LongAttributes.hpp>
#include <Hex/ios_generated.h>
#include <Hex/hex_generated.h>
#include <Hex/hex-agent-data_generated.h>
#include <Hex/AppInfo.hpp>
#include <Hex/HandledException.hpp>
#include <Hex/jserror_generated.h>


namespace NewRelic {
    namespace Hex {
        namespace Report {
            class AgentData {
            public:
                AgentData(const std::shared_ptr<StringAttributes>& stringAttributes,
                          const std::shared_ptr<BooleanAttributes>& booleanAttributes,
                          const std::shared_ptr<DoubleAttributes>& doubleAttributes,
                          const std::shared_ptr<LongAttributes>& longAttributes,
                          const std::shared_ptr<AppInfo>& applicationInfo,
                          std::shared_ptr<HandledException> handledException);

                Offset<fbs::HexAgentData> serialize(flatbuffers::FlatBufferBuilder& builder) const;

            private:
                const std::shared_ptr<StringAttributes>& _stringAttributes;
                const std::shared_ptr<BooleanAttributes>& _booleanAttributes;
                const std::shared_ptr<DoubleAttributes>& _doubleAttributes;
                const std::shared_ptr<LongAttributes>& _longAttributes;
                const std::shared_ptr<AppInfo>& _applicationInfo;
                std::shared_ptr<HandledException> _handledException;

            };
        }
    }
}
#endif //LIBMOBILEAGENT_AGENTDATA_HPP
