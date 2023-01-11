//  Copyright © 2023 New Relic. All rights reserved.

#include <Analytics/Constants.hpp>
#include "UserActionEvent.hpp"

namespace NewRelic{
    const std::string UserActionEvent::__eventType = std::string(__kNRMA_RET_mobileUserAction);
UserActionEvent::UserActionEvent(unsigned long long timestamp_epoch_millis,
                                         double session_elapsed_time_sec,
                                         AttributeValidator& attributeValidator)
        : AnalyticEvent(std::make_shared<std::string>(__eventType),
                        timestamp_epoch_millis,
                        session_elapsed_time_sec,
                        attributeValidator) {}


void UserActionEvent::put(std::ostream& os) const {
        os << UserActionEvent::__eventType << AnalyticEvent::_delimiter;
    }


}
