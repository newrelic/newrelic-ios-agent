//  Copyright © 2023 New Relic. All rights reserved.

#ifndef LIBMOBILEAGENT_IGUIDGENERATOR_HPP
#define LIBMOBILEAGENT_IGUIDGENERATOR_HPP
#include <stdlib.h>
namespace NewRelic {
namespace Connectivity {
template<typename T>
class IGuidGenerator {
public:
    // Uses arc4random_buf (CSPRNG) instead of an LCG seeded by a 32-bit-truncated
    // timestamp, which produced colliding trace/span IDs across processes that
    // generated GUIDs in the same clock tick.
    static T generateGuid() {
        T value = 0;
        arc4random_buf(&value, sizeof(value));
        return value;
    }
};
}
}
#endif //LIBMOBILEAGENT_IGUIDGENERATOR_HPP
