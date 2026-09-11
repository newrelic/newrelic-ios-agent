//  Copyright © 2026 New Relic. All rights reserved.

#ifndef LIBMOBILEAGENT_VIEWEVENT_HPP
#define LIBMOBILEAGENT_VIEWEVENT_HPP

#include <Analytics/AnalyticEvent.hpp>
#include <Analytics/EventDeserializer.hpp>

namespace NewRelic {
    /*
     * The built-in event behind view-lifecycle (MobileView) and view-timing
     * (MobileViewTiming) data.
     *
     * Unlike UserActionEvent, the event type is a constructor parameter rather than a
     * class-static: one class serves both event types, which differ only in that name.
     * EventDeserializer therefore dispatches on the __kNRMA_RET_mobileView /
     * __kNRMA_RET_mobileViewTiming constants directly instead of on a static member.
     */
    class ViewEvent : public AnalyticEvent {
        friend class EventManager;
        friend class EventDeserializer;
    protected:
        ViewEvent(const char* eventType,
                  unsigned long long timestamp_epoch_millis,
                  double session_elapsed_time_sec,
                  AttributeValidator& attributeValidator);

    public:
        virtual void put(std::ostream& os) const;
    };
}

#endif //LIBMOBILEAGENT_VIEWEVENT_HPP
