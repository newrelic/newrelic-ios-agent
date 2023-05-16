//
// Created by Bryce Buchanan on 6/12/17.
//  Copyright © 2023 New Relic. All rights reserved.
//

#ifndef LIBMOBILEAGENT_CONTEXT_HPP
#define LIBMOBILEAGENT_CONTEXT_HPP

#include <Hex/BooleanAttributes.hpp>
#include <Hex/StringAttributes.hpp>
#include <Hex/LongAttributes.hpp>
#include <Hex/DoubleAttributes.hpp>
#include <Hex/HandledException.hpp>
#include <Hex/AgentData.hpp>
#include <Analytics/AttributeValidator.hpp>
#include <Hex/HexReport.hpp>

#include <JSON/json_st.hh>
#include <Analytics/AttributeBase.hpp>

namespace NewRelic {
    namespace Hex {
        class HexContext {
        public:
            HexContext();

            virtual void finalize();

            std::shared_ptr<flatbuffers::FlatBufferBuilder> getBuilder();

        private:
            std::shared_ptr<flatbuffers::FlatBufferBuilder> builder;
        };
    }
}

#endif //LIBMOBILEAGENT_CONTEXT_HPP
