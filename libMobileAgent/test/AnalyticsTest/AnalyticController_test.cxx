#include <Analytics/AnalyticsController.hpp>
#include <Connectivity/Facade.hpp>
#include <memory>
#include <gmock/gmock.h>
#include <ostream>
#include <Utilities/ApplicationContext.hpp>
#include <Utilities/Application.hpp>
#include "PersistentStoreHelper.hpp"

using ::testing::Eq;
using ::testing::Test;

namespace NewRelic {

    class AnalyticsControllerTest : public ::testing::Test {
    public:
        unsigned long long epoch_time_ms;
        std::string sessionDataPathString;
        const char *sessionDataPath;
        PersistentStore<std::string, AnalyticEvent> eventStore;
        PersistentStore<std::string, BaseValue> attributeStore;

    public:
        AnalyticsControllerTest() : Test(),
                                    epoch_time_ms(
                                            (unsigned long long) std::chrono::duration_cast<std::chrono::milliseconds>(
                                                    std::chrono::system_clock().now().time_since_epoch()).count()),
                                    sessionDataPathString(""), // std::to_string(epoch_time_ms)),
                                    sessionDataPath(sessionDataPathString.c_str()),
                                    eventStore(AnalyticsController::getEventDupStoreName(),
                                               sessionDataPath,
                                               &EventManager::newEvent),
                                    attributeStore(AnalyticsController::getAttributeDupStoreName(),
                                                   sessionDataPath,
                                                   &Value::createValue) {
        }

        void SetUp() {
            Application::getInstance().setContext(ApplicationContext("accountId","applicationId"));
        }

        virtual void TearDown() {
            AnalyticsController controller(epoch_time_ms, sessionDataPath, eventStore, attributeStore);
            remove(controller.getPersistentAttributeStoreName());
            remove(controller.getAttributeDupStoreName());
            remove(controller.getEventDupStoreName());
            remove(eventStore.getFullStorePath());
            remove(attributeStore.getFullStorePath());
            remove(sessionDataPath);

            Application::getInstance().setContext(ApplicationContext("",""));
        }
    };

    TEST_F(AnalyticsControllerTest, testInteractionEvent) {
        AnalyticsController controller(epoch_time_ms, sessionDataPath, eventStore, attributeStore);

        ASSERT_TRUE(controller.addInteractionEvent("display viewcontroller", 1.43));
        ASSERT_TRUE(controller.addSessionEndAttribute());
    }

    TEST_F(AnalyticsControllerTest, testNetworkErrorEvent) {
        NetworkRequestData someRequestData = NetworkRequestData("http://google.com/v1/api",
                                                                "google.com",
                                                                "/v1/api",
                                                                "GET",
                                                                "wifi",
                                                                "application/txt",
                                                                0);
        NetworkRequestData someOtherRequestData = NetworkRequestData("http://newrelic.com/v1/mobile/",
                                                                     "newrelic.com",
                                                                     "/v1/mobile/",
                                                                     "GET",
                                                                     "3G",
                                                                     "application/txt",
                                                                     1);
        NetworkRequestData emptyRequestData = NetworkRequestData("",
                                                                 "",
                                                                 nullptr,
                                                                 "POST",
                                                                 "",
                                                                 "",
                                                                 0);

        NetworkResponseData someBadNetworkResponse = NetworkResponseData(-1001, 0, 1.0, nullptr);
        NetworkResponseData someBadHttpResponse = NetworkResponseData(404, 20, 100.1, nullptr, nullptr, nullptr);
        AnalyticsController controller(epoch_time_ms, sessionDataPath, eventStore, attributeStore);

        auto payload = Connectivity::Facade::getInstance().newPayload();

        ASSERT_TRUE(controller.addNetworkErrorEvent(someRequestData, someBadNetworkResponse, std::move(payload)));
        ASSERT_TRUE(controller.addHTTPErrorEvent(someOtherRequestData, someBadHttpResponse, std::move(payload)));
        ASSERT_FALSE(controller.addHTTPErrorEvent(emptyRequestData, someBadHttpResponse, std::move(payload)));
    }

    TEST_F(AnalyticsControllerTest, testVariousNetworkErrors) {
        NetworkRequestData failedRequest = NetworkRequestData("https://api.newrelic.com/api/v1/mobile",
                                                              "newrelic.com",
                                                              "/v1/mobile/",
                                                              "GET",
                                                              "wifi",
                                                              "application/txt",
                                                              200);

        NetworkResponseData failedResponse = NetworkResponseData(-1001, 100, 0.9, "network failure");

    auto payload = Connectivity::Facade::getInstance().newPayload();

        AnalyticsController controller(epoch_time_ms, sessionDataPath, eventStore, attributeStore);

        auto result = controller.addNetworkErrorEvent(failedRequest, failedResponse, std::move(payload));
        ASSERT_TRUE(result);
    }


TEST_F(AnalyticsControllerTest, testRequestEvent) {
    AnalyticsController controller(epoch_time_ms, sessionDataPath, eventStore, attributeStore);
    NetworkRequestData someRequestData = NetworkRequestData("http://newrelic.com/v1/mobile/",
                                                            "newrelic.com",
                                                            "/v1/mobile/",
                                                            "GET",
                                                            "3G",
                                                            "application/txt",
                                                            1);
    NetworkRequestData emptyRequestData = NetworkRequestData("",
                                                             "",
                                                             nullptr,
                                                             "POST",
                                                             "",
                                                             "",
                                                             0);

    NetworkResponseData someOkHttpResponse = NetworkResponseData(200, 20, 1.2);
    NetworkResponseData someBadHttpResponse = NetworkResponseData(400, 0, 10);

    auto payload = Connectivity::Facade::getInstance().startTrip();

    ASSERT_TRUE(controller.addRequestEvent(someRequestData, someOkHttpResponse, std::move(payload)));
    ASSERT_TRUE(controller.addRequestEvent(someRequestData, someOkHttpResponse, std::move(payload)));
    ASSERT_FALSE(controller.addRequestEvent(emptyRequestData, someBadHttpResponse, std::move(payload)));
}


    TEST_F(AnalyticsControllerTest, testRetreiveJSON) {
        AnalyticsController controller(epoch_time_ms, sessionDataPath, eventStore, attributeStore);

        auto event = controller.newEvent("hello!");
        event->addAttribute("blah", "blah");
        event->addAttribute("pewpew", 123);

        controller.addEvent(event);

        auto json = controller.getEventsJSON(true);
    }



    TEST_F(AnalyticsControllerTest, testReservedWords) {
        AnalyticsController controller(epoch_time_ms, sessionDataPath, eventStore, attributeStore);

        ASSERT_FALSE(controller.addSessionAttribute("newRelic12345", 5.0f)); //NewRelic is reserved
        ASSERT_FALSE(controller.addSessionAttribute("nr.NewRelic12345", 5.0f)); //NewRelic is reserved
        ASSERT_FALSE(controller.addSessionAttribute("type", 5.0f)); //NewRelic is reserved
        ASSERT_FALSE(controller.addSessionAttribute("timestamp", 5.0f)); //NewRelic is reserved
        ASSERT_FALSE(controller.addSessionAttribute("category", 5.0f)); //NewRelic is reserved
        ASSERT_FALSE(controller.addSessionAttribute("appId", 5.0f)); //NewRelic is reserved
        ASSERT_FALSE(controller.addSessionAttribute("appName", 5.0f)); //NewRelic is reserved
        ASSERT_FALSE(controller.addSessionAttribute("uuid", 5.0f)); //NewRelic is reserved
        ASSERT_FALSE(controller.addSessionAttribute("eventType", 5.0f)); //NewRelic is reserved
        ASSERT_FALSE(controller.addSessionAttribute("accountId", 5.0f)); //NewRelic is reserved
        ASSERT_FALSE(controller.addSessionAttribute("sessionId", 5.0f)); //NewRelic is reserved
        ASSERT_FALSE(controller.addSessionAttribute("", ""));
        ASSERT_FALSE(controller.addSessionAttribute("", "asdf"));
    }

    TEST_F(AnalyticsControllerTest, testPersistence) {
        AnalyticsController *controller = new AnalyticsController(epoch_time_ms,
                                                                  sessionDataPath,
                                                                  eventStore,
                                                                  attributeStore);
        ASSERT_TRUE(controller->addSessionAttribute("hello", "world", true));
        controller->attributeStore().synchronize();
        attributeStore.synchronize();

        delete controller;

        AnalyticsController second(epoch_time_ms, sessionDataPath, eventStore, attributeStore);

        second.attributeStore().synchronize();

        auto json = second.getSessionAttributeJSON(); // should pull persistent store.

        ASSERT_EQ("world", (*json)["hello"].as_string());
    }

    TEST_F(AnalyticsControllerTest, testDuplicateStores) {
        AnalyticsController controller(epoch_time_ms, sessionDataPath, eventStore, attributeStore);

        controller.addSessionAttribute("hello", "world");
        controller.addEvent(controller.newEvent("pewpew"));

        eventStore.synchronize();
        attributeStore.synchronize();

        auto eventJSON = controller.fetchDuplicatedEvents(eventStore, false);
        auto attributeJSON = controller.fetchDuplicatedAttributes(attributeStore, false);

        ASSERT_EQ("pewpew", (*eventJSON)[0]["name"].as_string());
        ASSERT_EQ("world", (*attributeJSON)["hello"].as_string());
    }

    TEST_F(AnalyticsControllerTest, testBoolInput) {
        AnalyticsController controller(epoch_time_ms, sessionDataPath, eventStore, attributeStore);
        bool value = true;
        ASSERT_TRUE(controller.addSessionAttribute("thisIsTrue", value));
        ASSERT_TRUE(controller.addSessionAttribute("thisIsFalse",false));

        attributeStore.synchronize();

        auto attributeJSON = controller.fetchDuplicatedAttributes(attributeStore, false);

        ASSERT_EQ(true,(*attributeJSON)["thisIsTrue"].as_bool());
        ASSERT_EQ(false,(*attributeJSON)["thisIsFalse"].as_bool());
        controller.clearSessionAttributes();
    }

    TEST_F(AnalyticsControllerTest, testInvalidInputs) {
        AnalyticsController controller(epoch_time_ms, sessionDataPath, eventStore, attributeStore);
        bool result = false;
//        bool addSessionAttribute(const char* name, const char* value);
        {
            const char *value = NULL;
            ASSERT_NO_THROW(result = controller.addSessionAttribute("", ""));
            ASSERT_FALSE(result);
            ASSERT_NO_THROW(result = controller.addSessionAttribute(value, value));
            ASSERT_FALSE(result);
        }

//        bool addSessionAttribute(const char *name, double value);
        {
            double value = -100.0f;
            ASSERT_NO_THROW(result = controller.addSessionAttribute("", value));
            ASSERT_FALSE(result);
            ASSERT_NO_THROW(result = controller.addSessionAttribute(NULL, value));
            ASSERT_FALSE(result);
        }

        //bool addSessionAttribute(const char* name, long long value);
        {
            long long value = -100;
            ASSERT_NO_THROW(result = controller.addSessionAttribute("", value));
            ASSERT_FALSE(result);
            ASSERT_NO_THROW(result = controller.addSessionAttribute(NULL, value));
            ASSERT_FALSE(result);
        }

//        bool addSessionAttribute(const char* name, unsigned long long value);
        {
            unsigned long long value = 100;
            ASSERT_NO_THROW(result = controller.addSessionAttribute("", value));
            ASSERT_FALSE(result);
            ASSERT_NO_THROW(result = controller.addSessionAttribute(NULL, value));
            ASSERT_FALSE(result);
        }
//        bool addSessionAttribute(const char* name, const char* value, bool persistent);
        {
            const char *value = NULL;
            ASSERT_NO_THROW(result = controller.addSessionAttribute("", "", false));
            ASSERT_FALSE(result);
            ASSERT_NO_THROW(result = controller.addSessionAttribute(NULL, value, false));
            ASSERT_FALSE(result);

            ASSERT_NO_THROW(result = controller.addSessionAttribute("", "", true));
            ASSERT_FALSE(result);
            ASSERT_NO_THROW(result = controller.addSessionAttribute(NULL, value, true));
            ASSERT_FALSE(result);
        }
//        bool addSessionAttribute(const char *name, double value, bool persistent);
        {
            double value = 100.0f;
            ASSERT_NO_THROW(result = controller.addSessionAttribute("", value, false));
            ASSERT_FALSE(result);
            ASSERT_NO_THROW(result = controller.addSessionAttribute(NULL, value, false));
            ASSERT_FALSE(result);

            ASSERT_NO_THROW(result = controller.addSessionAttribute("", value, true));
            ASSERT_FALSE(result);
            ASSERT_NO_THROW(result = controller.addSessionAttribute(NULL, value, true));
            ASSERT_FALSE(result);
        }
//        bool addSessionAttribute(const char* name, long long value, bool persistent);
        {
            long long value = 100;
            ASSERT_NO_THROW(result = controller.addSessionAttribute("", value, false));
            ASSERT_FALSE(result);
            ASSERT_NO_THROW(result = controller.addSessionAttribute(NULL, value, false));
            ASSERT_FALSE(result);

            ASSERT_NO_THROW(result = controller.addSessionAttribute("", value, true));
            ASSERT_FALSE(result);
            ASSERT_NO_THROW(result = controller.addSessionAttribute(NULL, value, true));
            ASSERT_FALSE(result);
        }
//        bool addSessionAttribute(const char* name, unsigned long long value, bool persistent);
        {
            unsigned long long value = 100;
            ASSERT_NO_THROW(result = controller.addSessionAttribute("", value, false));
            ASSERT_FALSE(result);
            ASSERT_NO_THROW(result = controller.addSessionAttribute(NULL, value, false));
            ASSERT_FALSE(result);

            ASSERT_NO_THROW(result = controller.addSessionAttribute("", value, true));
            ASSERT_FALSE(result);
            ASSERT_NO_THROW(result = controller.addSessionAttribute(NULL, value, true));
            ASSERT_FALSE(result);
        }


//        bool incrementSessionAttribute(const char *name, double value);
        {
            double value = 123.0f;
            ASSERT_NO_THROW(result = controller.incrementSessionAttribute("", value));
            ASSERT_FALSE(result);
            ASSERT_NO_THROW(result = controller.incrementSessionAttribute(NULL, value));
            ASSERT_FALSE(result);
        }

//        bool incrementSessionAttribute(const char *name, double value, bool persistent);
        {
            double value = 123.0f;
            ASSERT_NO_THROW(result = controller.incrementSessionAttribute("", value, false));
            ASSERT_FALSE(result);
            ASSERT_NO_THROW(result = controller.incrementSessionAttribute(NULL, value, false));
            ASSERT_FALSE(result);
            ASSERT_NO_THROW(result = controller.incrementSessionAttribute("", value, true));
            ASSERT_FALSE(result);
            ASSERT_NO_THROW(result = controller.incrementSessionAttribute(NULL, value, true));
            ASSERT_FALSE(result);
        }
//
//        bool removeSessionAttribute(const char* name);
        {
            ASSERT_NO_THROW(result = controller.removeSessionAttribute(""));
            ASSERT_FALSE(result);
            ASSERT_NO_THROW(result = controller.removeSessionAttribute(NULL));
            ASSERT_FALSE(result);
        }

    }

    TEST_F(AnalyticsControllerTest, testBreadcrumbEvent) {
        AnalyticsController controller(epoch_time_ms, sessionDataPath, eventStore, attributeStore);
        auto event = controller.newBreadcrumbEvent();

        ASSERT_TRUE(event != nullptr);
    }

    TEST_F(AnalyticsControllerTest, testCustomAttributesBadInput) {
        AnalyticsController controller(epoch_time_ms, sessionDataPath, eventStore, attributeStore);
        ASSERT_EQ(nullptr, controller.newCustomEvent(""));
        ASSERT_EQ(nullptr, controller.newCustomEvent(" "));
        ASSERT_EQ(nullptr, controller.newCustomEvent(" Hello!"));
        ASSERT_EQ(nullptr, controller.newCustomEvent(__kNRMA_RET_mobileSession));

        ASSERT_TRUE(nullptr != controller.newCustomEvent("testCustomEvent"));

        ASSERT_EQ(nullptr, controller.newCustomEvent("Mobile"));
    }

    TEST_F(AnalyticsControllerTest, testInvalidSpaces) {
        AnalyticsController controller(epoch_time_ms, sessionDataPath, eventStore, attributeStore);
        ASSERT_FALSE(controller.addSessionAttribute(" Hello!","blahblahblah"));
        ASSERT_FALSE(controller.addSessionAttribute("       Hello!","blahblahblah"));
        ASSERT_TRUE(controller.addSessionAttribute("Hello!"," blahblahblah"));

        ASSERT_TRUE(controller.addSessionAttribute("hello","blah"));


        auto event = controller.newEvent("asdfasdf");
        ASSERT_THROW(event->addAttribute(" asdfasdf","fjdlk"), std::invalid_argument);
    }

    TEST_F(AnalyticsControllerTest, testInvalidAttributeInputs) {
        bool result = false;
        AnalyticsController controller(epoch_time_ms, sessionDataPath, eventStore, attributeStore);

//        bool addSessionAttribute(const char* name, const char* value);
        {
            const char *value = NULL;
            ASSERT_NO_THROW(result = controller.addSessionAttribute("", ""));
            ASSERT_FALSE(result);
            ASSERT_NO_THROW(result = controller.addSessionAttribute(NULL, value));
            ASSERT_FALSE(result);
        }

//        bool addSessionAttribute(const char *name, double value);
        {
            double value = -100.0f;
            ASSERT_NO_THROW(result = controller.addSessionAttribute("", value));
            ASSERT_FALSE(result);
            ASSERT_NO_THROW(result = controller.addSessionAttribute(NULL, value));
            ASSERT_FALSE(result);
        }

        //bool addSessionAttribute(const char* name, long long value);
        {
            long long value = -100;
            ASSERT_NO_THROW(result = controller.addSessionAttribute("", value));
            ASSERT_FALSE(result);
            ASSERT_NO_THROW(result = controller.addSessionAttribute(NULL, value));
            ASSERT_FALSE(result);
        }

//        bool addSessionAttribute(const char* name, unsigned long long value);
        {
            unsigned long long value = 100;
            ASSERT_NO_THROW(result = controller.addSessionAttribute("", value));
            ASSERT_FALSE(result);
            ASSERT_NO_THROW(result = controller.addSessionAttribute(NULL, value));
            ASSERT_FALSE(result);
        }


//        bool addSessionAttribute(const char* name, const char* value, bool persistent);
        {
            const char *value = NULL;
            ASSERT_NO_THROW(result = controller.addSessionAttribute("", "", false));
            ASSERT_FALSE(result);
            ASSERT_NO_THROW(result = controller.addSessionAttribute(NULL, value, false));
            ASSERT_FALSE(result);

            ASSERT_NO_THROW(result = controller.addSessionAttribute("", "", true));
            ASSERT_FALSE(result);
            ASSERT_NO_THROW(result = controller.addSessionAttribute(NULL, value, true));
            ASSERT_FALSE(result);
        }
//        bool addSessionAttribute(const char *name, double value, bool persistent);
        {
            double value = 100.0f;
            ASSERT_NO_THROW(result = controller.addSessionAttribute("", value, false));
            ASSERT_FALSE(result);
            ASSERT_NO_THROW(result = controller.addSessionAttribute(NULL, value, false));
            ASSERT_FALSE(result);

            ASSERT_NO_THROW(result = controller.addSessionAttribute("", value, true));
            ASSERT_FALSE(result);
            ASSERT_NO_THROW(result = controller.addSessionAttribute(NULL, value, true));
            ASSERT_FALSE(result);
        }
//        bool addSessionAttribute(const char* name, long long value, bool persistent);
        {
            long long value = 100;
            ASSERT_NO_THROW(result = controller.addSessionAttribute("", value, false));
            ASSERT_FALSE(result);
            ASSERT_NO_THROW(result = controller.addSessionAttribute(NULL, value, false));
            ASSERT_FALSE(result);

            ASSERT_NO_THROW(result = controller.addSessionAttribute("", value, true));
            ASSERT_FALSE(result);
            ASSERT_NO_THROW(result = controller.addSessionAttribute(NULL, value, true));
            ASSERT_FALSE(result);
        }
//        bool addSessionAttribute(const char* name, unsigned long long value, bool persistent);
        {
            unsigned long long value = 100;
            ASSERT_NO_THROW(result = controller.addSessionAttribute("", value, false));
            ASSERT_FALSE(result);
            ASSERT_NO_THROW(result = controller.addSessionAttribute(NULL, value, false));
            ASSERT_FALSE(result);

            ASSERT_NO_THROW(result = controller.addSessionAttribute("", value, true));
            ASSERT_FALSE(result);
            ASSERT_NO_THROW(result = controller.addSessionAttribute(NULL, value, true));
            ASSERT_FALSE(result);
        }


//        bool incrementSessionAttribute(const char *name, double value);
        {
            double value = 123.0f;
            ASSERT_NO_THROW(result = controller.incrementSessionAttribute("", value));
            ASSERT_FALSE(result);
            ASSERT_NO_THROW(result = controller.incrementSessionAttribute(NULL, value));
            ASSERT_FALSE(result);
        }

//        bool incrementSessionAttribute(const char *name, double value, bool persistent);
        {
            double value = 123.0f;
            ASSERT_NO_THROW(result = controller.incrementSessionAttribute("", value, false));
            ASSERT_FALSE(result);
            ASSERT_NO_THROW(result = controller.incrementSessionAttribute(NULL, value, false));
            ASSERT_FALSE(result);
            ASSERT_NO_THROW(result = controller.incrementSessionAttribute("", value, true));
            ASSERT_FALSE(result);
            ASSERT_NO_THROW(result = controller.incrementSessionAttribute(NULL, value, true));
            ASSERT_FALSE(result);
        }
//
//        bool removeSessionAttribute(const char* name);
        {
            ASSERT_NO_THROW(result = controller.removeSessionAttribute(""));
            ASSERT_FALSE(result);
            ASSERT_NO_THROW(result = controller.removeSessionAttribute(NULL));
            ASSERT_FALSE(result);
        }


    }

    TEST_F(AnalyticsControllerTest, testBadEventInputs) {
        AnalyticsController controller(epoch_time_ms, sessionDataPath, eventStore, attributeStore);

        std::shared_ptr<AnalyticEvent> event;
        ASSERT_NO_THROW(event = controller.newEvent(""));
        ASSERT_TRUE(event == nullptr);

        bool result = false;
        ASSERT_NO_THROW(result = controller.addInteractionEvent("", 100));
        ASSERT_FALSE(result);

        result = false;
        ASSERT_NO_THROW(result = controller.addEvent(nullptr));
        ASSERT_FALSE(result);
    }

    TEST_F(AnalyticsControllerTest, testClearSessionAttributes) {
        AnalyticsController *controller = new AnalyticsController(epoch_time_ms, sessionDataPath, eventStore,
                                                                  attributeStore);
        ASSERT_TRUE(controller->addSessionAttribute("hello", "world", true));
        ASSERT_TRUE(controller->addSessionAttribute("hello1", "world", true));
        ASSERT_TRUE(controller->addSessionAttribute("hello2", "world", true));
        ASSERT_TRUE(controller->addSessionAttribute("hello3", "world", true));

        auto json = controller->getSessionAttributeJSON();
        NRJSON::JsonObject jsonObject = NRJSON::JsonObject(*json);
        ASSERT_EQ(4, jsonObject.size());

        controller->clearSessionAttributes();
        json = controller->getSessionAttributeJSON();
        jsonObject = NRJSON::JsonObject(*json);
        ASSERT_EQ(0, jsonObject.size());

        delete controller;
    }

    TEST_F(AnalyticsControllerTest, testBackupDuplicates) {
        AnalyticsController controller(epoch_time_ms, sessionDataPath, eventStore, attributeStore);

        controller.addSessionAttribute("hello", "world");
        controller.addEvent(controller.newEvent("pewpew"));

        eventStore.synchronize();
        attributeStore.synchronize();

        auto map = attributeStore.load();
        ASSERT_EQ(1, map.size());

        // swap should backup the store file, return any cached data, and clear the object's cache
        map = attributeStore.swap();
        ASSERT_EQ(1, map.size());

        map = attributeStore.load();
        ASSERT_EQ(0, map.size());

        ASSERT_TRUE(PersistentStoreHelper::storeExists(attributeStore.getFullStorePath()));
        ASSERT_TRUE(PersistentStoreHelper::storeIsEmpty(attributeStore.getFullStorePath()));

        std::string backupStorePath = std::string(attributeStore.getFullStorePath()) + ".bak";
        ASSERT_FALSE(PersistentStoreHelper::storeIsEmpty(backupStorePath.c_str()));

        remove(backupStorePath.c_str());
    }
    TEST_F(AnalyticsControllerTest, testEventJSONOutput) {
        AnalyticsController controller(epoch_time_ms, sessionDataPath, eventStore, attributeStore);
        const char* json = "{\"hello\":\"world\"}";

        std::string expectedOutput{ "[\n{\n\"category\": \"Custom\",\n\"eventType\": \"Mobile\",\n\"name\": \"{\\\"hello\\\":\\\"world\\\"}\",\n\"timeSinceLoad\": 0,\n\"timestamp\": 1438986983763\n}\n]"};

        controller.addSessionAttribute(json,json);
        controller.addEvent(controller.newEvent(json));
        auto jsonOutput = controller.getSessionAttributeJSON();
        std::stringstream s;
        s << *jsonOutput;
        ASSERT_TRUE(s.str().compare(expectedOutput));
    }

}
