//
// Created by Bryce Buchanan on 6/12/17.
//

#ifndef LIBMOBILEAGENT_CONTEXT_HPP
#define LIBMOBILEAGENT_CONTEXT_HPP

#include "BooleanAttributes.hpp"
#include "StringAttributes.hpp"
#include "LongAttributes.hpp"
#include "DoubleAttributes.hpp"
#include "HandledException.hpp"
#include "AgentData.hpp"
#include <Analytics/AttributeValidator.hpp>
#include "HexReport.hpp"

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
