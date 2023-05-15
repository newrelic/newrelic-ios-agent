//  Copyright © 2023 New Relic. All rights reserved.

#ifndef LIBMOBILEAGENT_ICATFACADE_HPP
#define LIBMOBILEAGENT_ICATFACADE_HPP

#include <memory>

#include <Connectivity/Payload.hpp>

namespace NewRelic {
namespace Connectivity {
class IFacade {
public:
    virtual std::unique_ptr<Payload> newPayload()=0;
    virtual std::unique_ptr<Payload> startTrip()=0;
};
} // namespace Connectivity
} // namespace NewRelic

#endif //LIBMOBILEAGENT_ICATFACADE_HPP
