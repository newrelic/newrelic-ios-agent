//
// Created by Bryce Buchanan on 6/13/17.
//

#ifndef LIBMOBILEAGENT_FRAME_HPP
#define LIBMOBILEAGENT_FRAME_HPP

#include "ios_generated.h"
#include "hex_generated.h"

using namespace com::newrelic::mobile;
using namespace flatbuffers;
namespace NewRelic {
    namespace Hex {
        namespace Report {
            class Frame {
            enum Enum {
                native,
                hybrid
            };
            public:
                // Native Stack Trace
                Frame(const char* value,
                      uint64_t address);
                // Hybrid Stack Trace
                Frame(const char* className,
                      const char* methodName,
                      const char* fileName,
                      int64_t lineNumber);

                Offset<fbs::hex::Frame> serialize(flatbuffers::FlatBufferBuilder& builder) const;

                static uint64_t frameStringToAddress(const char* frame);

            private:
                std::string _value;
                int64_t _lineNumber;
                uint64_t _address;
                std::string _className;
                std::string _methodName;
                std::string _fileName;
                Enum _type;
            };
        }
    }
}


#endif //LIBMOBILEAGENT_FRAME_HPP
