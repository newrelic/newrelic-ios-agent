//
// Created by Bryce Buchanan on 5/19/17.
//  Copyright © 2023 New Relic. All rights reserved.
//

#include "RequestEvent.hpp"

namespace NewRelic {
    const std::string RequestEvent::__eventType = std::string("MobileRequest");
    RequestEvent::RequestEvent(unsigned long long timestamp_epoch_millis,
                               double session_eplased_time_sec,
                               std::unique_ptr<const Connectivity::Payload> payload,
                               AttributeValidator& attributeValidator)
            : IntrinsicEvent(std::make_shared<std::string>(__eventType),
                             std::move(payload),
                             timestamp_epoch_millis,
                             session_eplased_time_sec,
                             attributeValidator)
    {}

    void RequestEvent::put(std::ostream& os) const {
        os << RequestEvent::__eventType << AnalyticEvent::_delimiter;
    }
}
