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
     *
     * `category` is added in generateJSONObject() rather than as an attribute, because
     * "category" is a reserved key and the attribute validator would reject it.
     */
    class ViewEvent : public AnalyticEvent {
        friend class EventManager;
        friend class EventDeserializer;
    private:
        std::string _category;
    protected:
        ViewEvent(const char* eventType,
                  const char* category,
                  unsigned long long timestamp_epoch_millis,
                  double session_elapsed_time_sec,
                  AttributeValidator& attributeValidator);

    public:
        virtual const std::string& getCategory() const;

        virtual void put(std::ostream& os) const;
        virtual std::shared_ptr<NRJSON::JsonObject> generateJSONObject() const;
    };
}

#endif //LIBMOBILEAGENT_VIEWEVENT_HPP
