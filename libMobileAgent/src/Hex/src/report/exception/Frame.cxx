//
// Created by Bryce Buchanan on 6/13/17.
//  Copyright © 2023 New Relic. All rights reserved.
//

#include "Frame.hpp"

using namespace com::newrelic::mobile;
using namespace flatbuffers;
using namespace NewRelic::Hex::Report;

// NOTE on the null coalescing below: constructing a std::string from a null
// const char* is undefined behavior (char_traits::length -> strlen(nullptr) ->
// SIGSEGV), and it is NOT a catchable exception, so a caller-side try/catch
// cannot save us. Every one of these arguments originates from
// -[NSString UTF8String], which returns nullptr when the receiver is nil, and
// the _Nonnull annotations on the ObjC side are unenforced across a Swift
// bridge. Guard here so a nil symbol name can never take down the host app.
Frame::Frame(const char* value,
             uint64_t address) : _value(value ? value : ""), _className(""), _methodName(""),
                                 _fileName(""), _lineNumber(0), _address(address), _type(native) {}

Frame::Frame(const char* className,
             const char* methodName,
             const char* fileName,
             int64_t lineNumber) : _value(""),
                                   _className(className ? className : ""),
                                   _methodName(methodName ? methodName : ""),
                                   _fileName(fileName ? fileName : ""),
                                   _lineNumber(lineNumber), _address(0), _type(hybrid) {}

Offset<fbs::hex::Frame> Frame::serialize(flatbuffers::FlatBufferBuilder& builder) const {

    // `hybrid` is handled first so that `native` can share the block with
    // `default`. Previously this switch covered both enumerators with no
    // `default:` and no trailing return, so any _type value outside the
    // enumeration fell off the end of a non-void function — undefined
    // behavior, and in an optimized build typically a jump to garbage.
    // Serializing an unexpected type as a native frame yields a well-formed
    // (if sparse) frame instead.
    switch (_type) {
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
        case native:
        default: {
            auto value = builder.CreateString(_value);
            auto frameBuilder = fbs::hex::FrameBuilder(builder);

            frameBuilder.add_value(value);

            frameBuilder.add_address(_address);

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
