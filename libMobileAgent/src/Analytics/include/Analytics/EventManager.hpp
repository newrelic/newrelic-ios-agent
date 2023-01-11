//  Copyright © 2023 New Relic. All rights reserved.

#include <vector>
#include <mutex>
#include <Analytics/NetworkErrorEvent.hpp>
#include <Analytics/BreadcrumbEvent.hpp>
#include <Analytics/RequestEvent.hpp>

#include "CustomMobileEvent.hpp"
#include "InteractionAnalyticEvent.hpp"
#include "SessionAnalyticEvent.hpp"
#include "UserActionEvent.hpp"
#include "CustomEvent.hpp"
#include "PersistentStore.hpp"

#ifndef __EventManager_H_
#define __EventManager_H_
namespace NewRelic {

    enum EventType {
        Interaction = 0,
        Crash,
        Custom,
        Session
    };

    class EventManager {
    friend class AnalyticsController;
    private :
        mutable std::recursive_mutex _eventsMutex;
        std::vector<std::shared_ptr<AnalyticEvent>> _events;
        PersistentStore<std::string,AnalyticEvent>&  _eventDuplicationStore;

        //helper function for deserialization.
        static std::stringstream readStreamToDelimiter(std::istream& is, char delimiter);
        //_oldest_event_timestamp_ms is used in didReachMaxQueueTime().
        // 0 is a special case that results in "false" for didReachMaxQueueTime();
        unsigned long long _oldest_event_timestamp_ms = 0; //special case!
        int _total_attempted_inserts = 0;

    public:
        EventManager(PersistentStore<std::string,AnalyticEvent>& store);

        virtual ~EventManager();

        bool addEvent(std::shared_ptr<AnalyticEvent> event);


        //deprecated, replaced with newCustomEvent
        static std::shared_ptr<CustomMobileEvent> newCustomMobileEvent(const char* name,
                                                                         unsigned long long timestamp_epoch_millis,
                                                                         double session_elapsed_time_sec,
                                                                         AttributeValidator& attributeValidator);

        static std::shared_ptr<BreadcrumbEvent> newBreadcrumbEvent(unsigned long long timestamp_epoch_millis,
                                                                   double session_elapsed_time_sec,
                                                                   AttributeValidator &attributeValidator);

        static std::shared_ptr<CustomEvent> newCustomEvent(const char* eventType,
                                                             unsigned long long timestamp_epoch_millis,
                                                             double session_elapsed_time_sec,
                                                             AttributeValidator& attributeValidator);

        static std::shared_ptr<InteractionAnalyticEvent> newInteractionAnalyticEvent(const char *name,
                                                                                     unsigned long long timestamp_epoch_millis,
                                                                                     double session_elapsed_time_sec,
                                                                                     AttributeValidator &attributeValidator);

        static std::shared_ptr<SessionAnalyticEvent> newSessionAnalyticEvent(unsigned long long timestamp_epoch_millis,
                                                                             double session_elapsed_time_sec,
                                                                             AttributeValidator& attributeValidator);

        static std::shared_ptr<UserActionEvent>
        newUserActionEvent(unsigned long long timestamp_epoch_millis,
                           double session_elapsed_time_sec,
                           AttributeValidator &attributeValidator);


        static std::shared_ptr<NetworkErrorEvent> newNetworkErrorEvent(unsigned long long timestamp_epoch_millis,
                                                                       double session_elapsed_time_sec,
                                                                       const char* encodedResponseBody,
                                                                       const char* appDataHeader,
                                                                       std::unique_ptr<const Connectivity::Payload> payload,
                                                                       AttributeValidator& attributeValidator);

        static std::shared_ptr<RequestEvent> newRequestEvent(unsigned long long timestamp_epoch_millis,
                                                             double session_elapsed_time_sec,
                                                             std::unique_ptr<const Connectivity::Payload> payload,
                                                             AttributeValidator& attributeValidator);

        static std::shared_ptr<AnalyticEvent> newEvent(std::istream &is);


        std::shared_ptr<NRJSON::JsonArray> toJSON() const;
        static std::shared_ptr<NRJSON::JsonArray> toJSON(std::vector<std::shared_ptr<AnalyticEvent>> events);

        static std::string createKey(std::shared_ptr<AnalyticEvent> event);

        //_events buffer controls
        virtual int getRemovalIndex(); //returns a number between 0 and _total_attempted_inserts. used when MaxBufferSize is reached.
        void setMaxBufferTime(unsigned int seconds); //sets max buffer time
        void setMaxBufferSize(unsigned int size); //sets max buffer size
        bool didReachMaxQueueTime(unsigned long long currentTimestamp_ms); //checks if oldest event timestamp exceededs max queue time
        void empty(); //removes all events in _events;
    };
}
#endif
