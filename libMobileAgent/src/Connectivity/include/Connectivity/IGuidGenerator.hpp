//  Copyright © 2023 New Relic. All rights reserved.

#ifndef LIBMOBILEAGENT_IGUIDGENERATOR_HPP
#define LIBMOBILEAGENT_IGUIDGENERATOR_HPP
#include <random>
namespace NewRelic {
namespace Connectivity {
template<typename T>
class IGuidGenerator {
public:
    static T generateGuid() {
        // Use a single persistent engine, seeded once from a non-deterministic
        // source. The previous implementation re-seeded a fresh engine with a
        // truncated `unsigned int` timestamp on EVERY call, so two calls within
        // the same clock tick returned identical values. newGUID32() concatenates
        // two generateGuid() calls, so that produced 128-bit trace ids whose two
        // 64-bit halves were identical (e.g. "7b2961adf3fdf1cd" twice) and made
        // trace ids collide across unrelated requests (newrelic/newrelic-ios-agent#772).
        static thread_local std::mt19937_64 generator{std::random_device{}()};
        std::uniform_int_distribution<T> distribution{}; //default constructor does 0 - type_max
        return distribution(generator);
    }
};
}
}
#endif //LIBMOBILEAGENT_IGUIDGENERATOR_HPP
