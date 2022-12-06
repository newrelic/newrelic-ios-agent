//
// Created by Bryce Buchanan on 2/5/16.
//
#include "Analytics/Deserializer.hpp"
namespace NewRelic {
    std::stringstream Deserializer::readStreamToDelimiter(std::istream& is, char delimiter) {
        std::stringstream oss;
        is.get(*oss.rdbuf(), delimiter);
        return oss;
    }
}

