
#include <sstream>
#include <iostream>
#include <iomanip>

#include "Connectivity/GuidGenerator.hpp"

namespace NewRelic {
namespace Connectivity {
std::__1::basic_string<char, std::__1::char_traits<char>, std::__1::allocator<char>>
GuidGenerator::newGUID() {
    std::stringstream s;
    s << std::hex << std::setw(16) << std::setfill('0') << GuidGenerator::generateGuid();
    return s.str();
}
std::__1::basic_string<char, std::__1::char_traits<char>, std::__1::allocator<char>>
GuidGenerator::newGUID32() {
    std::stringstream s;
    s << std::hex << std::setw(16) << std::setfill('0') << GuidGenerator::generateGuid() << std::setw(16) << std::setfill('0') << GuidGenerator::generateGuid();
    return s.str();
}
}
}
