//
// Created by Bryce Buchanan on 7/19/17.
//  Copyright © 2023 New Relic. All rights reserved.
//
#include "ios_generated.h"
#include "hex_generated.h"
#include "session-attributes_generated.h"
#include "agent-data_generated.h"
#include <Analytics/AttributeValidator.hpp>
#include <Analytics/AttributeBase.hpp>
#include "HandledException.hpp"
#include "AppInfo.hpp"
#include "BooleanAttributes.hpp"
#include "StringAttributes.hpp"
#include "LongAttributes.hpp"
#include "DoubleAttributes.hpp"

#ifndef LIBMOBILEAGENT_HEXREPORT_HPP
#define LIBMOBILEAGENT_HEXREPORT_HPP

using namespace com::newrelic::mobile;
using namespace flatbuffers;
namespace NewRelic {
    namespace Hex {
        namespace Report {
            class HexReport {
            public:
                flatbuffers::Offset<fbs::AgentData> finalize(FlatBufferBuilder& builder) const; //throws

                HexReport(std::shared_ptr<Report::HandledException> exception,
                          const std::shared_ptr<AppInfo>& applicationInfo,
                          const ::NewRelic::AttributeValidator& attributeValidator);

                //setAttributes(...)
                //used primarily for setting session attributes directly from Analytics
                void setAttributes(std::map<std::string, std::shared_ptr<AttributeBase>> attributes);

                //setAttribute(...)
                //used primarily for setting custom attributes from the recordHandledException API
                void setAttribute(const char* key,
                                  long long value);

                void setAttribute(const char* key,
                                  double value);

                void setAttribute(const char* key,
                                  const char* value);

                void setAttribute(const char* key,
                                  bool value);

                const std::shared_ptr<BooleanAttributes>& getBooleanAttributes() const;

                const std::shared_ptr<StringAttributes>& getStringAttributes() const;

                const std::shared_ptr<LongAttributes>& getLongAttributes() const;

                const std::shared_ptr<DoubleAttributes>& getDoubleAttributes() const;

            private:
                std::shared_ptr<HandledException> _exception;
                std::shared_ptr<BooleanAttributes> _booleanAttributes;
                std::shared_ptr<StringAttributes> _stringAttributes;
                std::shared_ptr<LongAttributes> _longAttributes;
                std::shared_ptr<DoubleAttributes> _doubleAttributes;
                const std::shared_ptr<AppInfo>& _applicationInfo;
                const AttributeValidator& _attributeValidator;
            };
        }
    }
}
#endif //LIBMOBILEAGENT_HEXREPORT_HPP
