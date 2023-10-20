//  Copyright © 2023 New Relic. All rights reserved.

#include <regex>
#include <Analytics/AnalyticsController.hpp>

namespace NewRelic {

#define strlens(s) (s==nullptr?0:strlen(s))

    static const unsigned int MAX_NAME_LEN = 256;
    static const unsigned int MAX_VALUE_SIZE_BYTES = 4096;

    const char *AnalyticsController::ATTRIBUTE_STORE_DB_FILENAME = "persistentAttributeStore.txt";
    const char *AnalyticsController::ATTRIBUTE_DUP_STORE_DB_FILENAME = "attributeDupStore.txt";
    const char *AnalyticsController::EVENT_DUP_STORE_DB_FILENAME = "eventsDupStore.txt";


    //only allow alphanumeric, _ (covered in \w), colon, and spaces.

    const AttributeValidator &AnalyticsController::getAttributeValidator() const {
        return this->_attributeValidator;
    }

    bool AnalyticsController::addEvent(std::shared_ptr <AnalyticEvent> event) {
        bool success;
        try {
            success = _eventManager.addEvent(event);
        } catch (...) {
            LLOG_ERROR("Unable to add event.");
            success = false;
        }

        return success;
    }

    unsigned long long int AnalyticsController::getCurrentTime_ms() { //throws std::logic_error
        long long epoch_time_ms = std::chrono::duration_cast<std::chrono::milliseconds>(
                std::chrono::system_clock().now().time_since_epoch()).count();
        if (epoch_time_ms < 0) {
            throw std::logic_error("current time returned < 0!");
        }

        return (unsigned long long) epoch_time_ms;
    }

    double AnalyticsController::getCurrentSessionDuration_sec(unsigned long long current_time_ms) const {
        long long currentSessionLength_ms = current_time_ms - _session_start_time_ms;
        if (currentSessionLength_ms < 0) {
            throw std::logic_error("calculated session duration is less than 0!");
        }
        return currentSessionLength_ms / 1000.0;
    }

    AnalyticsController::AnalyticsController(unsigned long long sessionStartTime_ms, const char *sharedPath,
                                             PersistentStore <std::string, AnalyticEvent> &eventDupStore,
                                             PersistentStore <std::string, BaseValue> &attributeDupStore) :
            _session_start_time_ms(sessionStartTime_ms),//todo: ensure these things are floats when sent to server
            _attributeValidator(
                    [=](const char *name) {

                        if (strlens(name) == 0) {
                            throw std::invalid_argument(
                                    "name cannot be empty.");
                        }

                        std::string const s{name};

                        if (s[0] == ' ') {
                            std::ostringstream oss;
                            oss << "' ' is not allowed as the first character: \"" << s << "\".";
                            throw std::invalid_argument(oss.str());
                        }

                        auto cReservedKeysIterator = std::find(
                                _reserved_keys.cbegin(),
                                _reserved_keys.cend(), s);
                        if (cReservedKeysIterator != _reserved_keys.cend()) {
                            std::ostringstream oss;
                            oss << "Attempted to add reserved key: \"" << *cReservedKeysIterator << "\"";
                            throw std::invalid_argument(oss.str());
                        }
                        for (auto cIterator = _reserved_key_prefix.cbegin();
                             cIterator < _reserved_key_prefix.cend(); cIterator++) {
                            if (s.find(*cIterator) == 0) {
                                std::ostringstream oss;
                                oss << "Attempted to add key: \"" << s << "\", which starts with a reserved prefix: \""
                                    <<
                                    *cIterator << "\"";
                                throw std::invalid_argument(oss.str());
                            }
                        }

                        if (strlen(name) >= MAX_NAME_LEN) {
                            std::ostringstream oss;
                            oss << "key length beyond limit, " << MAX_NAME_LEN;
                            throw std::invalid_argument(oss.str());
                        }
                        return true;
                    },

                    [](const char *value) {

                        if (strlens(value) == 0) {
                            throw std::invalid_argument(
                                    "value cannot be empty.");
                        }

                        if (strlen(value) * sizeof(char) >= MAX_VALUE_SIZE_BYTES) {
                            std::ostringstream oss;
                            oss << "value exceeded maximum byte size, " << MAX_VALUE_SIZE_BYTES;
                            throw std::invalid_argument(oss.str());
                        }
                        return true;
                    },

                    [=](const char *eventType) {
                        if (strlens(eventType) == 0) {
                            throw std::invalid_argument(
                                    "eventType cannot be empty.");
                        }

                        auto cReservedKeysIterator = std::find(
                                _reserved_eventTypes.cbegin(),
                                _reserved_eventTypes.cend(), eventType);
                        if (cReservedKeysIterator != _reserved_eventTypes.cend()) {
                            std::ostringstream oss;
                            oss << "Attempted to add reserved key: \"" << *cReservedKeysIterator << "\"";
                            throw std::invalid_argument(oss.str());
                        }

                        if (eventType[0] == ' ') {
                            std::ostringstream oss;
                            oss << "' ' is not allowed as the first character: \"" << eventType << "\".";
                            throw std::invalid_argument(oss.str());
                        }

                        return true;
                    }),
            _attributeDuplicationStore(attributeDupStore),
            _attributeStore(ATTRIBUTE_STORE_DB_FILENAME, sharedPath,
                            (std::shared_ptr<BaseValue>(*)(std::istream & )) & Value::createValue),
            _eventsDuplicationStore(eventDupStore),
            _eventManager(_eventsDuplicationStore),
            _sessionAttributeManager(_attributeStore,
                                     _attributeDuplicationStore,
                                     _attributeValidator) {}

    void AnalyticsController::setMaxEventBufferTime(unsigned int seconds) {
        _eventManager.setMaxBufferTime(seconds);
    }


    PersistentStore <std::string, BaseValue> &AnalyticsController::attributeStore() {
        return _attributeStore;
    }

    void AnalyticsController::setMaxEventBufferSize(unsigned int size) {
        _eventManager.setMaxBufferSize(size);
    }

    bool AnalyticsController::didReachMaxEventBufferTime() {
        return _eventManager.didReachMaxQueueTime(getCurrentTime_ms()); //throws std::logic_error
    }

    bool AnalyticsController::addSessionEndAttribute() {
        try {
            unsigned long long current_time_ms = AnalyticsController::getCurrentTime_ms(); //throws std::logic_error
            auto attribute = Attribute<double>::createAttribute("sessionDuration",
                                                                [](const char *) {
                                                                    return true;
                                                                },
                                                                ((current_time_ms / 1000.0) -
                                                                 (_session_start_time_ms / 1000.0)),
                                                                [](double) {
                                                                    return true;
                                                                });
            return AnalyticsController::addNRAttribute(attribute);
        } catch (std::invalid_argument &e) {
            //adding log under verbose as this is an internal agent method, and wont be called by customers.
            LLOG_VERBOSE("Unable to add \"session end\" attribute: %s", e.what());
            return false;
        } catch (std::logic_error &e) {
            LLOG_VERBOSE(e.what());
            return false;
        } catch (...) {
            LLOG_VERBOSE("Unknown exception occurred.");
            return false;
        }
    }

    bool AnalyticsController::addUserActionEvent(const char *functionName,
                                             const char *targetObject,
                                             const char *label,
                                             const char *accessibility,
                                             const char *tapCoordinates,
                                             const char *actionType,
                                             const char *controlFrame,
                                             const char *orientation) {
        try {
            unsigned long long current_time_ms = AnalyticsController::getCurrentTime_ms();//throws std::logic_error
            auto event = _eventManager.newUserActionEvent(current_time_ms,
                                                          getCurrentSessionDuration_sec(current_time_ms),
                                                          _attributeValidator);

            if ((strlens(functionName) > 0)) {
                event->addAttribute(__kNRMA_RA_methodExecuted, functionName);
            }

            if ((strlens(targetObject) > 0)) {
                event->addAttribute(__kNRMA_RA_targetObject, targetObject);
            }

            if ((strlens(label) > 0)) {
                event->addAttribute(__kNRMA_RA_label, label);
            }

            if ((strlens(accessibility) > 0)) {
                event->addAttribute(__kNRMA_RA_accessibility, accessibility);
            }

            if ((strlens(tapCoordinates) > 0)) {
                event->addAttribute(__kNRMA_RA_touchCoordinates, tapCoordinates);
            }

            if ((strlens(actionType) > 0)) {
                event->addAttribute(__kNMRA_RA_actionType, actionType);
            }

            if ((strlens(controlFrame) > 0)) {
                event->addAttribute(__kNRMA_RA_frame, controlFrame);
            }

            if ((strlens(orientation) > 0)) {
                event->addAttribute(__kNRMA_RA_orientation, orientation);
            }

            return addEvent(event);

        } catch (std::logic_error &e) {
            LLOG_VERBOSE("Failed to add tracked gesture: %s", e.what());
            return false;
        } catch (std::exception &e) {
            LLOG_VERBOSE("Failed to add tracked gesture: %s", e.what());
            return false;
        } catch (...) {
            LLOG_VERBOSE("Failed to add tracked gesture: unknown error.");
            return false;
        }
    }

    bool AnalyticsController::addInteractionEvent(const char *name, double duration_sec) {
        try {
            if ((strlens(name) == 0)) {
                //adding log under verbose as this is an internal agent method, and wont be called by customers.
                LLOG_VERBOSE("Cannot add interaction event with an empty name.");
                return false;
            }
            unsigned long long current_time_ms = AnalyticsController::getCurrentTime_ms(); //throws std::logic_error

            //throws std::out_of_range, std::length_error
            auto event = _eventManager.newInteractionAnalyticEvent(name,
                                                                   current_time_ms,
                                                                   getCurrentSessionDuration_sec(current_time_ms),
                                                                   _attributeValidator);

            if (!event->addAttribute(InteractionAnalyticEvent::kInteractionTraceDurationKey, duration_sec))
                return false;
            return addEvent(event);

        } catch (std::logic_error &e) {
            //adding log under verbose as this is an internal agent method, and wont be called by customers.
            LLOG_VERBOSE(e.what());
            return false;
        } catch (...) {
            LLOG_VERBOSE("Unknown exception occurred.");
            return false;
        }
    }

    bool AnalyticsController::addSessionEvent() {
        try {
            auto currentTime_ms = getCurrentTime_ms(); //throws std::logic_error
            auto sessionDuration_sec = getCurrentSessionDuration_sec(currentTime_ms);
            auto event = EventManager::newSessionAnalyticEvent(currentTime_ms,
                                                               sessionDuration_sec,
                                                               _attributeValidator);

            if (event != nullptr) {
                return addEvent(event);
            }

        } catch (...) {
            LLOG_VERBOSE("Unable to add session event.");
            return false;
        }
        return false;
    }

    void addGraphQLHeaders(std::map<std::string, std::string> graphQLHeaders, std::shared_ptr<IntrinsicEvent> event) {
        std::map<std::string, std::string>::iterator it
        = graphQLHeaders.begin();
        // Iterating over the map using Iterator till map end.
        while (it != graphQLHeaders.end()) {
            // Accessing the key
            std::string key = it->first;
            // Accessing the value
            std::string value = it->second;
            event->addAttribute(key.c_str(), value.c_str());
            // iterator incremented to point next item
            it++;
        }
    }

    bool AnalyticsController::addRequestEvent(const NewRelic::NetworkRequestData& requestData,
                                              const NewRelic::NetworkResponseData& responseData,
                                              std::unique_ptr<const Connectivity::Payload> payload) {

        try {

            // copy DT fields before payload gets std::move()
            std::string distributedTracingId("");
            std::string traceId("");
            std::map<std::string, std::string> graphQLHeaders;
            bool addDistributedTracing = false;
            if (payload != nullptr) {
                distributedTracingId = payload->getId();
                traceId = payload->getTraceId();
                addDistributedTracing = payload->getDistributedTracing();
                graphQLHeaders = payload->getGraphQLHeaders();
            }
            
            auto currentTime_ms = getCurrentTime_ms(); //throws std::logic_error
            auto sessionDuration_sec = getCurrentSessionDuration_sec(currentTime_ms);
            auto event = EventManager::newRequestEvent(currentTime_ms,
                                                       sessionDuration_sec,
                                                       std::move(payload),
                                                       _attributeValidator);

            auto requestUrl = requestData.getRequestUrl();
            auto requestDomain = requestData.getRequestDomain();
            auto requestPath = requestData.getRequestPath();
            auto requestMethod = requestData.getRequestMethod();
            auto connectionType = requestData.getConnectionType();
            auto bytesSent = requestData.getBytesSent();
            auto contentType = requestData.getContentType();
            auto responseTime = responseData.getResponseTime();
            auto bytesReceived = responseData.getBytesReceived();
            auto statusCode = responseData.getStatusCode();

            if ((strlens(requestUrl) == 0)) {
                LLOG_INFO("unable to add NetworkErrorEvent with empty URL.");
                return false;
            }

            if (event != nullptr) {
                event->addAttribute(__kNRMA_Attrib_requestUrl, requestUrl);
                event->addAttribute(__kNRMA_Attrib_responseTime, responseTime);

                if (addDistributedTracing) {
                    event->addAttribute(__kNRMA_Attrib_dtGuid, distributedTracingId.c_str());
                    event->addAttribute(__kNRMA_Attrib_dtId, distributedTracingId.c_str());
                    event->addAttribute(__kNRMA_Attrib_dtTraceId, traceId.c_str());
                }
                
                if ((strlens(requestDomain) > 0)) {
                    event->addAttribute(__kNRMA_Attrib_requestDomain, requestDomain);
                }

                if ((strlens(requestPath) > 0)) {
                    event->addAttribute(__kNRMA_Attrib_requestPath, requestPath);
                }

                if ((strlens(requestMethod) > 0)) {
                    event->addAttribute(__kNRMA_Attrib_requestMethod, requestMethod);
                }

                if ((strlens(connectionType) > 0)) {
                    event->addAttribute(__kNRMA_Attrib_connectionType, connectionType);
                }

                if (bytesReceived != 0) {
                    event->addAttribute(__kNRMA_Attrib_bytesReceived, bytesReceived);
                }

                if (bytesSent != 0) {
                    event->addAttribute(__kNRMA_Attrib_bytesSent, bytesSent);
                }

                if (statusCode != 0) {
                    event->addAttribute(__kNRMA_Attrib_statusCode, statusCode);
                }

                if ((strlens(contentType) > 0)) {
                    event->addAttribute(__kNRMA_Attrib_contentType, contentType);
                }
                
                if(graphQLHeaders.size() != 0) {
                    addGraphQLHeaders(graphQLHeaders, event);
                }

                return _eventManager.addEvent(event);
            }
        } catch (const std::exception &ex) {
            LLOG_INFO("failed to add network Event: %s", ex.what());
        } catch (...) {
            LLOG_INFO("failed to add Network Error Event.");
        }
        return false;
    }

    bool AnalyticsController::addHTTPErrorEvent(const NewRelic::NetworkRequestData& requestData,
                                                const NewRelic::NetworkResponseData& responseData,
                                                std::unique_ptr<const Connectivity::Payload> payload) {
        try {
            auto event = createRequestErrorEvent(requestData, responseData, std::move(payload));

            if (event != nullptr) {
                event->addAttribute(__kNRMA_Attrib_errorType, __kNRMA_Val_errorType_HTTP);
                return _eventManager.addEvent(event);
            }
        } catch (const std::exception &ex) {
            LLOG_INFO("failed to add network Event: %s", ex.what());
        } catch (...) {
            LLOG_INFO("failed to add Network Error Event.");
        }

        return false;
    }

    bool AnalyticsController::addNetworkErrorEvent(const NewRelic::NetworkRequestData& requestData,
                                                   const NewRelic::NetworkResponseData& responseData,
                                                   std::unique_ptr<const Connectivity::Payload> payload) {
        try {
            auto event = createRequestErrorEvent(requestData, responseData, std::move(payload));

            if (event != nullptr) {
                event->addAttribute(__kNRMA_Attrib_errorType, __kNRMA_Val_errorType_Network);
                return _eventManager.addEvent(event);
            }

        } catch (const std::exception &ex) {
            LLOG_INFO("failed to add network Event: %s", ex.what());
        } catch (...) {
            LLOG_INFO("failed to add Network Error Event.");
        }

        return false;
    }


    std::shared_ptr<NetworkErrorEvent> AnalyticsController::createRequestErrorEvent(const NewRelic::NetworkRequestData& requestData,
                                                                                    const NewRelic::NetworkResponseData& responseData,
                                                                                    std::unique_ptr<const Connectivity::Payload> payload) {
        try {
            
            // copy DT fields before payload gets std::move()
            std::string distributedTracingId("");
            std::string traceId("");
            std::map<std::string, std::string> graphQLHeaders;
            bool addDistributedTracing = false;
            if (payload != nullptr) {
                distributedTracingId = payload->getId();
                traceId = payload->getTraceId();
                addDistributedTracing = payload->getDistributedTracing();
                graphQLHeaders = payload->getGraphQLHeaders();
            }
            
            auto requestUrl = requestData.getRequestUrl();
            auto requestDomain = requestData.getRequestDomain();
            auto requestPath = requestData.getRequestPath();
            auto requestMethod = requestData.getRequestMethod();
            auto connectionType = requestData.getConnectionType();
            auto bytesSent = requestData.getBytesSent();
            auto contentType = requestData.getContentType();
            auto appDataHeader = responseData.getAppDataHeader();
            auto encodedResponseBody = responseData.getEncodedResponseBody();
            auto responseTime = responseData.getResponseTime();
            auto bytesReceived = responseData.getBytesReceived();
            auto networkErrorMessage = responseData.getNetworkErrorMessage();
            auto networkErrorCode = responseData.getNetworkErrorCode();
            auto statusCode = responseData.getStatusCode();

            auto currentTime_ms = getCurrentTime_ms(); //throws std::logic_error
            auto sessionDuration_sec = getCurrentSessionDuration_sec(currentTime_ms);
            auto event = EventManager::newNetworkErrorEvent(currentTime_ms, sessionDuration_sec, encodedResponseBody,
                                                            appDataHeader, std::move(payload), _attributeValidator);

            if ((strlens(requestUrl) == 0)) {
                LLOG_INFO("unable to add NetworkErrorEvent with empty URL.");
                return nullptr;
            }
            if (event != nullptr) {
                
                if (addDistributedTracing) {
                    event->addAttribute(__kNRMA_Attrib_dtGuid, distributedTracingId.c_str());
                    event->addAttribute(__kNRMA_Attrib_dtId, distributedTracingId.c_str());
                    event->addAttribute(__kNRMA_Attrib_dtTraceId, traceId.c_str());
                }
                
                event->addAttribute(__kNRMA_Attrib_requestUrl, requestUrl);
                event->addAttribute(__kNRMA_Attrib_responseTime, responseTime);

                if ((strlens(requestDomain) > 0)) {
                    event->addAttribute(__kNRMA_Attrib_requestDomain, requestDomain);
                }

                if ((strlens(requestPath) > 0)) {
                    event->addAttribute(__kNRMA_Attrib_requestPath, requestPath);
                }

                if ((strlens(requestMethod) > 0)) {
                    event->addAttribute(__kNRMA_Attrib_requestMethod, requestMethod);
                }

                if ((strlens(connectionType) > 0)) {
                    event->addAttribute(__kNRMA_Attrib_connectionType, connectionType);
                }

                if (bytesReceived > 0) {
                    event->addAttribute(__kNRMA_Attrib_bytesReceived, bytesReceived);
                }

                if (bytesSent != 0) {
                    event->addAttribute(__kNRMA_Attrib_bytesSent, bytesSent);
                }

                if ((strlens(networkErrorMessage) > 0)) {
                    event->addAttribute(__kNRMA_Attrib_networkError, networkErrorMessage);
                }

                if ((strlens(contentType) > 0)) {
                    event->addAttribute(__kNRMA_Attrib_contentType, contentType);
                }

                if (networkErrorCode != 0) {
                    event->addAttribute(__kNRMA_Attrib_networkErrorCode, networkErrorCode);
                }

                if (statusCode != 0) {
                    event->addAttribute(__kNRMA_Attrib_statusCode, statusCode);
                }
              
                if(graphQLHeaders.size() != 0) {
                    addGraphQLHeaders(graphQLHeaders, event);
                }

                return event;
            }
        } catch (const std::exception &ex) {
            LLOG_INFO("failed to add network Event: %s", ex.what());
        } catch (...) {
            LLOG_INFO("failed to add Network Error Event.");
        }
        return nullptr;
    }


    bool AnalyticsController::incrementSessionAttribute(const char *name, unsigned long long value) {
        bool result;
        try {
            if ((strlens(name) == 0)) {
                LLOG_WARNING("Unable to increment session attribute with an empty name.");
                return false;
            }
            return _sessionAttributeManager.incrementAttribute(name, value);
        } catch (...) {
            LLOG_ERROR("Unable to increment session attribute.");
            result = false;
        }
        return result;
    }

    bool AnalyticsController::incrementSessionAttribute(const char *name, unsigned long long value, bool persistent) {
        bool result;
        try {
            if ((strlens(name) == 0)) {
                LLOG_WARNING("Unable to increment session attribute with an empty name.");
                return false;
            }
            return _sessionAttributeManager.incrementAttribute(name, value, persistent); //can throw system_error
        } catch (std::system_error &e) {
            LLOG_ERROR("Unable to increment session attribute \"%s\" : %s", name, e.what());
        } catch (...) {
            //most exceptions are caught within incrementAttributes(). This catch is a redundancy.
            LLOG_ERROR("Unable to increment session attribute.");
            result = false;
        }
        return result;
    }

    bool AnalyticsController::incrementSessionAttribute(const char *name, double value) {
        bool result;
        try {
            if ((strlens(name) == 0)) {
                LLOG_WARNING("Unable to increment session attribute with an empty name.");
                return false;
            }
            return _sessionAttributeManager.incrementAttribute(name, value);
        } catch (...) {
            LLOG_ERROR("Unable to increment session attribute.");
            result = false;
        }
        return result;
    }

    bool AnalyticsController::incrementSessionAttribute(const char *name, double value, bool persistent) {
        bool result;
        try {
            if ((strlens(name) == 0)) {
                LLOG_WARNING("Unable to increment session attribute with an empty name.");
                return false;
            }
            return _sessionAttributeManager.incrementAttribute(name, value, persistent); //can throw system_error
        } catch (std::system_error &e) {
            LLOG_ERROR("Unable to increment session attribute \"%s\" : %s", name, e.what());
        } catch (...) {
            //most exceptions are caught within incrementAttributes(). This catch is a redundancy.
            LLOG_ERROR("Unable to increment session attribute.");
            result = false;
        }
        return result;
    }

    bool AnalyticsController::addNRAttribute(std::shared_ptr <AttributeBase> attribute) {
        bool result;
        try {
            return _sessionAttributeManager.addNRAttribute(attribute);
        } catch (...) {
            //adding log under verbose as this is an internal agent method, and wont be called by customers.
            LLOG_VERBOSE("Unable to add private attribute.");
            result = false;
        }
        return result;
    }

    bool AnalyticsController::addSessionAttribute(const char *name, const char *value) {
        bool result;
        try {
            if ((strlens(name) == 0)) {
                LLOG_WARNING("Unable to add session attribute with an empty name.");
                return false;
            }
            result = _sessionAttributeManager.addSessionAttribute(name, value);
        } catch (...) {
            //adding log under verbose as this is an internal agent method, and wont be called by customers.
            LLOG_ERROR("Unable to add session attribute.");
            result = false;
        }
        return result;
    }

    bool AnalyticsController::addSessionAttribute(const char *name, double value) {
        try {
            if (strlens(name) == 0) {
                LLOG_WARNING("Unable to add session attribute with an empty name.");
                return false;
            }
            return _sessionAttributeManager.addSessionAttribute(name, value);
        } catch (...) {
            LLOG_ERROR("Unable to add session attribute");
            return false;
        }
    }

    bool AnalyticsController::addSessionAttribute(const char *name, long long value) {
        try {
            if (strlens(name) == 0) {
                LLOG_WARNING("Unable to add session attribute with an empty name.");
                return false;
            }
            return _sessionAttributeManager.addSessionAttribute(name, value);
        } catch (...) {
            //adding log under verbose as this is an internal agent method, and wont be called by customers.
            LLOG_ERROR("Unable to add session attribute.");
            return false;
        }
    }

    bool AnalyticsController::addSessionAttribute(const char *name, unsigned long long value) {
        try {
            if (strlens(name) == 0) {
                LLOG_WARNING("Unable to add session attribute with an empty name.");
                return false;
            }
            return _sessionAttributeManager.addSessionAttribute(name, value);
        } catch (...) {
            //adding log under verbose as this is an internal agent method, and wont be called by customers.
            LLOG_ERROR("Unable to add session attribute.");
            return false;
        }
    }

    bool AnalyticsController::addSessionAttribute(const char *name, bool value) {
        try {
            if (strlens(name) == 0) {
                LLOG_WARNING("Unable to add session attribute with an empty name.");
                return false;
            }
            return _sessionAttributeManager.addSessionAttribute(name, value);
        } catch (...) {
            //adding log under verbose as this is an internal agent method, and wont be called by customers.
            LLOG_ERROR("Unable to add session attribute.");
            return false;
        }
    }

    bool AnalyticsController::addSessionAttribute(const char *name, const char *value, bool persistent) {
        try {
            if (strlens(name) == 0) {
                LLOG_WARNING("Unable to add session attribute with an empty name.");
                return false;
            }

            if (strlens(value) == 0) {
                LLOG_WARNING("Unable to add session attribute with an empty value.");
                return false;
            }
            return _sessionAttributeManager.addSessionAttribute(name,
                                                                value,
                                                                persistent);
        } catch (...) {
            //adding log under verbose as this is an internal agent method, and wont be called by customers.
            LLOG_ERROR("Unable to add session attribute.");
            return false;
        }
    }

    bool AnalyticsController::addSessionAttribute(const char *name, double value, bool persistent) {
        try {
            if (strlens(name) == 0) {
                LLOG_WARNING("Unable to add session attribute with an empty name.");
                return false;
            }
            return _sessionAttributeManager.addSessionAttribute(name,
                                                                value,
                                                                persistent);
        } catch (...) {
            //adding log under verbose as this is an internal agent method, and wont be called by customers.
            LLOG_ERROR("Unable to add session attribute.");
            return false;
        }
    }

    bool AnalyticsController::addSessionAttribute(const char *name, long long value, bool persistent) {
        try {
            if (strlens(name) == 0) {
                LLOG_WARNING("Unable to add session attribute with an empty name.");
                return false;
            }
            return _sessionAttributeManager.addSessionAttribute(name,
                                                                value,
                                                                persistent);
        } catch (...) {
            //adding log under verbose as this is an internal agent method, and wont be called by customers.
            LLOG_ERROR("Unable to add session attribute.");
            return false;
        }
    }

    bool AnalyticsController::addSessionAttribute(const char *name, unsigned long long value, bool persistent) {
        try {
            if (strlens(name) == 0) {
                LLOG_WARNING("Unable to add session attribute with an empty name.");
                return false;
            }
            return _sessionAttributeManager.addSessionAttribute(name, value,
                                                                persistent);
        } catch (...) {
            //adding log under verbose as this is an internal agent method, and wont be called by customers.
            LLOG_ERROR("Unable to add session attribute.");
            return false;
        }
    }

    bool AnalyticsController::addSessionAttribute(const char *name, bool value, bool persistent) {
        try {
            if (strlens(name) == 0) {
                LLOG_WARNING("Unable to add session attribute with an empty name.");
                return false;
            }
            return _sessionAttributeManager.addSessionAttribute(name, value,
                                                                persistent);
        } catch (...) {
            //adding log under verbose as this is an internal agent method, and wont be called by customers.
            LLOG_ERROR("Unable to add session attribute.");
            return false;
        }
    }

    bool AnalyticsController::removeSessionAttribute(const char *name) {
        try {
            if (strlens(name) == 0) {
                LLOG_WARNING("Unable to remove session attribute with an empty name.");
                return false;
            }
            return _sessionAttributeManager.removeSessionAttribute(name);
        } catch (...) {
            //adding log under verbose as this is an internal agent method, and wont be called by customers.
            LLOG_ERROR("Unable to add session attribute.");
            return false;
        }
    }

    bool AnalyticsController::clearSessionAttributes() {
        try {
            return _sessionAttributeManager.clearSessionAttributes();
        } catch (...) {
            //adding log under verbose as this is an internal agent method, and wont be called by customers.
            LLOG_VERBOSE("Unable to clear session attributes.");
            return false;
        }
    }

    std::shared_ptr <BreadcrumbEvent> AnalyticsController::newBreadcrumbEvent() {
        try {
            auto currentTime_ms = getCurrentTime_ms(); //throws std::logic_error
            auto sessionDuration_sec = getCurrentSessionDuration_sec(currentTime_ms);
            return EventManager::newBreadcrumbEvent(currentTime_ms,
                                                    sessionDuration_sec,
                                                    _attributeValidator);
        } catch (std::exception &e) {
            LLOG_VERBOSE("Unable to create new Breadcrumb event.");
            return nullptr;
        } catch (...) {
            //adding log under verbose as this is an internal agent method, and wont be called by customers.
            LLOG_VERBOSE("Unable to create new Breadcrumb event.");
            return nullptr;
        }
    }

    std::shared_ptr <CustomEvent> AnalyticsController::newCustomEvent(const char *name) {
        try {
            if (strlens(name) == 0) {
                LLOG_ERROR("Unable to add event with an empty name.");
                return nullptr;
            }

            // prevent use of reserved eventTypes
            std::string const s = std::string{name};

            auto currentTime_ms = getCurrentTime_ms(); //throws std::logic_error
            auto sessionDuration_sec = getCurrentSessionDuration_sec(currentTime_ms);
            if (_attributeValidator.getEventTypeValidator()(name)) {
                return EventManager::newCustomEvent(name,
                                                    currentTime_ms,
                                                    sessionDuration_sec,
                                                    _attributeValidator);
            }
            return nullptr;
        } catch (std::exception &e) {
            LLOG_VERBOSE("Unable to create new event named \"%s\". %s", name, e.what());
            return nullptr;
        } catch (...) {
            //adding log under verbose as this is an internal agent method, and wont be called by customers.
            LLOG_VERBOSE("Unable to create new event named \"%s\".", name);
            return nullptr;
        }
    }

    std::shared_ptr <AnalyticEvent> AnalyticsController::newEvent(const char *name) {
        // 1. validate name (event manager will do this)
        // 2. create empty event (maybe pass constraints here?
        // 3. return event in ptr (caller will insert key/value attributes manually)
        try {
            if (strlens(name) == 0) {
                LLOG_ERROR("Unable to add event with an empty name.");
                return nullptr;
            }
            auto currentTime_ms = getCurrentTime_ms(); //throws std::logic_error
            auto sessionDuration_sec = getCurrentSessionDuration_sec(currentTime_ms);
            if (_attributeValidator.getValueValidator()(name)) {
                return EventManager::newCustomMobileEvent(name,
                                                          currentTime_ms,
                                                          sessionDuration_sec,
                                                          _attributeValidator);
            }
            return nullptr;
        } catch (...) {
            //adding log under verbose as this is an internal agent method, and wont be called by customers.
            LLOG_VERBOSE("Unable to create new event named \"%s\".", name);
            return nullptr;
        }
    }


    std::shared_ptr <NRJSON::JsonArray> AnalyticsController::getEventsJSON(bool clearEvents) {
        std::unique_lock <std::recursive_mutex> eventLock(_eventManager._eventsMutex, std::defer_lock);
        eventLock.lock();
        auto json = _eventManager.toJSON();

        if (clearEvents) {
            _eventManager.empty();
            _eventsDuplicationStore.clear();
        }
        return json;
    }

    std::shared_ptr <NRJSON::JsonObject> AnalyticsController::getSessionAttributeJSON() const {
        std::unique_lock <std::recursive_mutex> attributeLock(_sessionAttributeManager._attributesLock,
                                                              std::defer_lock);
        attributeLock.lock();

        std::shared_ptr <NRJSON::JsonObject> json;
        try {
            json = _sessionAttributeManager.generateJSONObject();
            return json;
        } catch (...) {
            //adding log under verbose as this is an internal agent method, and wont be called by customers.
            LLOG_VERBOSE("Unable to fetch attribute json");
            return nullptr;
        }
    }


    const std::map <std::string, std::shared_ptr<AttributeBase>> AnalyticsController::getSessionAttributes() const {
        return this->_sessionAttributeManager.getSessionAttributes();
    };


    std::shared_ptr <NRJSON::JsonArray> AnalyticsController::fetchDuplicatedEvents(
            PersistentStore <std::string, AnalyticEvent> &eventStore,
            bool shouldClearStore) {

        std::map <std::string, std::shared_ptr<AnalyticEvent>> events;
        if (shouldClearStore) {
            events = eventStore.swap();
        } else {
            events = eventStore.load();
        }
        std::vector <std::shared_ptr<AnalyticEvent>> vector;
        for (auto it = events.begin(); it != events.end(); it++) {
            vector.push_back(it->second);
        }
        return EventManager::toJSON(vector);
    }

    std::shared_ptr <NRJSON::JsonObject> AnalyticsController::fetchDuplicatedAttributes(
            PersistentStore <std::string, BaseValue> &attributeStore,
            bool shouldClearStore) {
        std::map <std::string, std::shared_ptr<BaseValue>> valuesMap;

        if (shouldClearStore) {
            valuesMap = attributeStore.swap();
        } else {
            valuesMap = attributeStore.load();
        }
        auto attributesMap = std::map < std::string, std::shared_ptr<AttributeBase>>
        {};
        for (auto it = valuesMap.cbegin(); it != valuesMap.cend(); it++) {
            attributesMap[it->first] = std::make_shared<AttributeBase>(AttributeBase(it->first, it->second));
        }

        if (shouldClearStore) {
            attributeStore.clear();
        }
        return SessionAttributeManager::generateJSONObject(attributesMap);
    }

    void AnalyticsController::clearEventsDuplicationStore() {
        _eventsDuplicationStore.clear();
    }

    void AnalyticsController::clearAttributesDuplicationStore() {
        _attributeDuplicationStore.clear();
    }

    const char *AnalyticsController::getPersistentAttributeStoreName() {
        return ATTRIBUTE_STORE_DB_FILENAME;
    }

    const char *AnalyticsController::getAttributeDupStoreName() {
        return ATTRIBUTE_DUP_STORE_DB_FILENAME;
    }

    const char *AnalyticsController::getEventDupStoreName() {
        return EVENT_DUP_STORE_DB_FILENAME;
    }

}
