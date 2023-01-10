//
// Created by Bryce Buchanan on 6/13/17.
//  Copyright © 2023 New Relic. All rights reserved.
//

#include "Frame.hpp"

using namespace com::newrelic::mobile;
using namespace flatbuffers;
using namespace NewRelic::Hex::Report;

Frame::Frame(const char* value,
             uint64_t address) : _value(value), _className(""), _methodName(""),
                                 _fileName(""), _lineNumber(0), _address(address), _type(native) {}

Frame::Frame(const char* className,
             const char* methodName,
             const char* fileName,
             int64_t lineNumber) : _value(""), _className(className), _methodName(methodName),
                                   _fileName(fileName), _lineNumber(lineNumber), _address(0), _type(hybrid) {}

Offset<fbs::hex::Frame> Frame::serialize(flatbuffers::FlatBufferBuilder& builder) const {


    switch (_type) {
        case native: {
            auto value = builder.CreateString(_value);
            auto frameBuilder = fbs::hex::FrameBuilder(builder);

            frameBuilder.add_value(value);

            frameBuilder.add_address(_address);

            return frameBuilder.Finish();
        }
        case hybrid: {
            auto className = builder.CreateString(_className);
            auto methodName = builder.CreateString(_methodName);
            auto fileName = builder.CreateString(_fileName);
            auto frameBuilder = fbs::hex::FrameBuilder(builder);

            frameBuilder.add_lineNumber(_lineNumber);
            frameBuilder.add_className(className);
            frameBuilder.add_methodName(methodName);
            frameBuilder.add_fileName(fileName);

            return frameBuilder.Finish();

        }
    }

}

// frame has the format "0 binaryname      0x00000000deadbeef optionalSymbol + line
uint64_t Frame::frameStringToAddress(const char* frame) {
    if (frame == nullptr) {
        return 0;
    }

    const size_t len = strlen(frame);
    if (len == 0) {
        return 0;
    }

    const char* end = frame + len;


    // Skip until we find a space, then skip that too.
    const char* cur = frame;

    while (*cur != ' ' && cur != end) cur++;
    while (*cur == ' ' && cur != end) cur++;

    // Skip the next token and space as well
    while (*cur != ' ' && cur != end) cur++;
    while (*cur == ' ' && cur != end) cur++;

    if (cur == end) {
        return 0; // unexpected end
    }

    if (*(cur++) != '0') {
        return 0; // not a start of a hex number
    }

    if (cur == end) {
        return 0; // unexpected end
    }

    if (*(cur++) != 'x') {
        return 0; // definitely not a hex number
    }

    return strtoull(cur, nullptr, 16);
}
