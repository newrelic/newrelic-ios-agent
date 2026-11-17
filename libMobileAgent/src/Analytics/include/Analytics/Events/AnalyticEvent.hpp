//  Copyright © 2023 New Relic. All rights reserved.

#ifndef __AnalyticEvent_H_
#define __AnalyticEvent_H_

#include <string>
#include <map>
#include <Utilities/BaseValue.hpp>
#include <Analytics/Attribute.hpp>
#include <Analytics/AttributeValidator.hpp>
#include <JSON/json.hh>

namespace NewRelic {
    class AnalyticEvent {
        friend class EventManager;
        friend class EventDeserializer;
    private:
        const std::shared_ptr<std::string> _eventType;
        unsigned long long _timestamp_epoch_millis;
        double _session_elapsed_time_sec;
        AttributeValidator& _attributeValidator;
        std::map<std::string, std::shared_ptr<AttributeBase>> _attributes;
        // In-memory only -- key for persisting via EventPersistenceBridge, not part of
        // the on-disk format; a deserialized event gets a freshly-minted one.
        std::string _eventUUID;
    protected:
        bool insertAttribute(std::shared_ptr<AttributeBase> attribute);

        AnalyticEvent(const std::shared_ptr<std::string> eventType,
                      unsigned long long timestamp_epoch_millis,
                      double session_elapsed_time_sec,
                      AttributeValidator& attributeValidator);


    public:
        static const char _delimiter = '\t';
        virtual ~AnalyticEvent();
        virtual const std::string& getEventType() const;
        virtual void put(std::ostream& os) const = 0;
        unsigned long long getAgeInMillis();
        const std::string& getEventUUID() const;

        AnalyticEvent(const AnalyticEvent& event);
        AnalyticEvent& operator=(const AnalyticEvent& event);
        friend bool operator==(const AnalyticEvent& lhs, const AnalyticEvent& rhs);
        virtual bool equal(const AnalyticEvent& event) const;

        bool addAttribute(const char *name, const char* value);
        bool addAttribute(const char *name, double value);
        bool addAttribute(const char *name, bool value);
        bool addAttribute(const char* name,
                          long long int value);
        bool addAttribute(const char* name,
                          unsigned long long int value);
        bool addAttribute(const char* name,
                          int value);
        bool addAttribute(const char* name,
                          unsigned int value);

        virtual std::shared_ptr<NRJSON::JsonObject> generateJSONObject()const;

        friend std::ostream& operator<<( std::ostream& os,const AnalyticEvent& event);


    };
}
#endif
