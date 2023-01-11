//
// Created by Bryce Buchanan on 2/3/16.
//  Copyright © 2023 New Relic. All rights reserved.
//


#ifndef LIBMOBILEAGENT_USERACTIONEVENT_HPP
#define LIBMOBILEAGENT_USERACTIONEVENT_HPP
#include "IntrinsicEvent.hpp"
#include "Analytics/EventDeserializer.hpp"

namespace NewRelic {
    class UserActionEvent : public AnalyticEvent {
        friend class EventManager;
        friend class EventDeserializer;
    private:
        static const std::string __eventType;
    protected:
        UserActionEvent(unsigned long long timestamp_epoch_millis,
                            double session_elapsed_time_sec,
                            AttributeValidator& attributeValidator);

    public:

        virtual void put(std::ostream& os) const;
    };
}

#endif //LIBMOBILEAGENT_USERACTIONEVENT_HPP
