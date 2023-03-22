//  Copyright © 2023 New Relic. All rights reserved.

#include <Analytics/Constants.hpp>
#include "NetworkErrorEvent.hpp"

namespace NewRelic {
    const std::string NetworkErrorEvent::__eventType = std::string(__kNRMA_RET_mobileRequestError);
    NetworkErrorEvent::NetworkErrorEvent(unsigned long long timestamp_epoch_millis,
                                         double session_elapsed_time_sec,
                                         const char* encodedResponseBody,
                                         const char* appDataHeader,
                                         std::unique_ptr<const Connectivity::Payload> payload,
                                         AttributeValidator& attributeValidator)
            : IntrinsicEvent(std::make_shared<std::string>(__eventType),
                             std::move(payload),
                             timestamp_epoch_millis,
                             session_elapsed_time_sec,
                             attributeValidator) {
        if (encodedResponseBody != nullptr && strlen(encodedResponseBody) > 0) {
            auto responseBodyAttribute = Attribute<const char*>::createAttribute(__kNRMA_RA_responseBody,
                                                                                 [](const char*) { return true; },
                                                                                 encodedResponseBody,
                                                                                 [](const char*) { return true; });
            insertAttribute(responseBodyAttribute);
        }

        if (appDataHeader != nullptr && strlen(appDataHeader) > 0) {
            auto appDataAttribute = Attribute<const char*>::createAttribute(__kNRMA_RA_appDataHeader,
                                                                            [](const char*) { return true; },
                                                                            appDataHeader,
                                                                            [](const char*) { return true; });
            insertAttribute(appDataAttribute);
        }
    }

    void NetworkErrorEvent::put(std::ostream& os) const {
        os << NetworkErrorEvent::__eventType << AnalyticEvent::_delimiter;
    }
}
