//
// Created by Bryce Buchanan on 6/12/17.
//  Copyright © 2023 New Relic. All rights reserved.
//

#include "AgentData.hpp"

using namespace flatbuffers;


NewRelic::Hex::Report::AgentData::AgentData(const std::shared_ptr<StringAttributes>& stringAttributes,
                                            const std::shared_ptr<BooleanAttributes>& booleanAttributes,
                                            const std::shared_ptr<DoubleAttributes>& doubleAttributes,
                                            const std::shared_ptr<LongAttributes>& longAttributes,
                                            const std::shared_ptr<AppInfo>& applicationInfo,
                                            std::shared_ptr<HandledException> handledException)
        : _stringAttributes(stringAttributes),
          _booleanAttributes(booleanAttributes),
          _doubleAttributes(doubleAttributes),
          _longAttributes(longAttributes),
          _applicationInfo(applicationInfo),
          _handledException(std::move(handledException)) {}

Offset<fbs::HexAgentData> NewRelic::Hex::Report::AgentData::serialize(flatbuffers::FlatBufferBuilder& builder) const {

    auto serializedHandledException = _handledException->serialize(builder);
    auto serializedApplicationInformation = _applicationInfo->serialize(builder);
    auto serializedBooleanAttributes = _booleanAttributes->serialize(builder);
    auto serializedDoubleAttributes = _doubleAttributes->serialize(builder);
    auto serializedLongAttributes = _longAttributes->serialize(builder);
    auto serializedStringAttributes = _stringAttributes->serialize(builder);


    auto agentDataBuilder = fbs::HexAgentDataBuilder(builder);
    agentDataBuilder.add_handledExceptions(serializedHandledException);
    agentDataBuilder.add_applicationInfo(serializedApplicationInformation);
    agentDataBuilder.add_boolAttributes(serializedBooleanAttributes);
    agentDataBuilder.add_doubleAttributes(serializedDoubleAttributes);
    agentDataBuilder.add_longAttributes(serializedLongAttributes);
    agentDataBuilder.add_stringAttributes(serializedStringAttributes);
    return agentDataBuilder.Finish();
}
