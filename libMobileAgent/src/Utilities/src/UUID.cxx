//  Copyright © 2023 New Relic. All rights reserved.

#include <sstream>
#include <iostream>
#include <iomanip>
#include "Utilities/UUID.hpp"
namespace NewRelic {


UUID UUID::createUUID() {
    return UUID::createUUID([]()->uint32_t {
        unsigned seed = static_cast<unsigned int>(std::chrono::system_clock::now().time_since_epoch().count());
        std::default_random_engine generator{seed};
        std::uniform_int_distribution<uint32_t> distribution{}; //default constructor does 0 - type_max
        return distribution(generator);
    });
}

UUID UUID::createUUID(std::function<uint32_t()> randomNumberGenerator) {
    auto uuid = UUID();

    // step 3 : all other bits are random

    uuid.time_low = randomNumberGenerator();

    uuid.node2_5 = randomNumberGenerator();

    auto value = randomNumberGenerator();

    uuid.time_mid = uint16_t(value >> 16);

    uuid.time_hi_and_version =  uuid.time_hi_and_version | (UUID::kTIME_BIT_MASK & (uint16_t)value);

    value = randomNumberGenerator();

    uuid.clk_seq = uuid.clk_seq | (UUID::kCLK_SEQ_BIT_MASK & (uint16_t)value);

    uuid.node0_1 = uint16_t(value >> 16);

    return uuid;
}

/*
 time-low "-" time-mid "-"
 time-high-and-version "-"
 clock-seq-and-reserved
 clock-seq-low "-" node
 */
std::string UUID::toString() {
    std::stringstream s;
    s << std::hex << std::setw(8) << std::setfill('0') << time_low << "-";
    s << std::hex << std::setw(4) << std::setfill('0') << time_mid << "-";
    s << std::setw(4) << std::setfill('0')  << std::hex << time_hi_and_version << "-";
    s << std::setw(4) << std::setfill('0')  << std::hex << clk_seq;
    s << "-";
    s << std::setw(4) << std::setfill('0')  << std::hex << node0_1;
    s << std::setw(8) << std::setfill('0') << std::hex << node2_5;
    return s.str();
}

uint32_t UUID::getTime_low() const {
    return time_low;
}

uint16_t UUID::getTime_mid() const {
    return time_mid;
}

uint16_t UUID::getTime_hi_and_version() const {
    return time_hi_and_version;
}

uint16_t UUID::getClk_seq() const {
    return clk_seq;
}

uint16_t UUID::getNode0_1() const {
    return node0_1;
}

uint32_t UUID::getNode2_5() const {
    return node2_5;
}
} // namespace NewRelic
