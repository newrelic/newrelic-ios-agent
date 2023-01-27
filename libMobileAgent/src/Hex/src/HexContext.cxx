//
// Created by Bryce Buchanan on 6/12/17.
//  Copyright © 2023 New Relic. All rights reserved.
//

#include <Utilities/String.hpp>
#include <Utilities/Boolean.hpp>
#include <Utilities/Number.hpp>
#include "Hex/HexContext.hpp"

using namespace NewRelic::Hex;
using namespace com::newrelic::mobile;


HexContext::HexContext() : builder(std::make_shared<flatbuffers::FlatBufferBuilder>()) {

}

std::shared_ptr<flatbuffers::FlatBufferBuilder> HexContext::getBuilder() {
    return builder;
}


void HexContext::finalize() {

}
