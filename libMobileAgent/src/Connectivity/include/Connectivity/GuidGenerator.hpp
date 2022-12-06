
#ifndef LIBMOBILEAGENT_GUIDGENERATOR_HPP
#define LIBMOBILEAGENT_GUIDGENERATOR_HPP

#include <cstdint>
#include "Connectivity/IGuidGenerator.hpp"
namespace NewRelic {
namespace Connectivity {
class GuidGenerator : public IGuidGenerator<uint64_t> {
public:
    static std::string newGUID();
    static std::string newGUID32();
};
}
}
#endif //LIBMOBILEAGENT_GUIDGENERATOR_HPP
