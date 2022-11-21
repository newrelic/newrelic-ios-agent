#include <Analytics/Events/AnalyticEvent.hpp>
#include <Analytics/AttributeBase.hpp>
#include <Utilities/Value.hpp>
#include <Utilities/Application.hpp>
#include <Analytics/EventManager.hpp>
#include <Connectivity/Facade.hpp>
#include <iostream>
#include <gmock/gmock.h>
#include <string>
#include <chrono>
#include <map>
#include <JSON/json.hh>

using ::testing::Eq;

#include <gtest/gtest.h>
#include <thread>
#include <Analytics/Constants.hpp>

using ::testing::Test;

namespace  NewRelic {

    class AnalyticEventTest : public ::testing::Test {
    public:
        const char *storeFilename = "pewpew.txt";
        unsigned long long epoch_time_ms;
        std::string sessionDataPathString;
        const char *sessionDataPath;
        PersistentStore<std::string, AnalyticEvent> store;
        AttributeValidator validator = (AttributeValidator([](const char *) { return true; },
                                                           [](const char *) { return true; },
                                                           [](const char *) { return true; }));

    protected:
        AnalyticEventTest() : Test(),
                              epoch_time_ms((unsigned long long) std::chrono::duration_cast<std::chrono::milliseconds>(
                                      std::chrono::system_clock().now().time_since_epoch()).count()),
                              sessionDataPathString(""), // std::to_string(epoch_time_ms)),
                              sessionDataPath(sessionDataPathString.c_str()),
                              store(PersistentStore<std::string, AnalyticEvent>(storeFilename, sessionDataPath,
                                                                                &EventManager::newEvent)) {
        }

    protected:
        virtual void SetUp() {
            Application::getInstance().setContext(ApplicationContext("accountId","applicationid"));
        }

        virtual void TearDown() {
            remove(store.getFullStorePath());
        }
    };

    class MockAnalyticEvent : public AnalyticEvent {
    private:
        std::string category = std::string("testCategory");
    public:

        AttributeValidator myValidator = AttributeValidator([](const char *) { return true; },
                                                            [](const char *) { return true; },
                                                            [](const char *) { return true; });

        MockAnalyticEvent(unsigned long long timestamp_epoch_millis,
                          unsigned long long session_elapsed_time_sec,
                          std::map<std::string const, std::shared_ptr<BaseValue> const> attributes) : AnalyticEvent(
                std::make_shared<std::string>("Mobile"), timestamp_epoch_millis, session_elapsed_time_sec, myValidator) {
        }

        virtual const std::string *getCategory() const {
            return &category;
        }
        virtual void put(std::ostream& os) const {

        }
    };

    TEST(AnalyticEvent, testGetAgeInMillis) {
        std::map<std::string const, std::shared_ptr<BaseValue> const> myMap;

        auto val = Value::createValue((unsigned long long) 123);
        std::shared_ptr<BaseValue> ptr = val;
        long long millis = std::chrono::duration_cast<std::chrono::milliseconds>(
                std::chrono::system_clock().now().time_since_epoch()).count();
        AnalyticEvent *event = new MockAnalyticEvent(1, 1, myMap);
        ASSERT_GT(event->getAgeInMillis(), 0);
        ASSERT_LE(event->getAgeInMillis(), millis);
        ASSERT_DOUBLE_EQ(event->getAgeInMillis() / 100l, millis / 100l); //todo: better test, no fail on edge case time
        delete(event);
    }

    TEST(AnalyticEvent, testStoreMap) {
//        std::map<std::string const* const, BaseValue const*const,std::less<const std::string*const>> *myMap = new std::map<std::string const*const, BaseValue const*const, std::less<const std::string*const>>();
//
//        std::string* str = new std::string("Hello");
//        String* myValue = new String("hello");
//        myMap->insert(std::pair<std::string const* const, BaseValue const*const>(str,myValue));
//        auto it = myMap->find(new std::string("Hello"));
//        ASSERT_FALSE(it == myMap->end());
//
//        const BaseValue * const mapValue = it->second;
//        const std::string*const strKey = it->first;
//        ASSERT_TRUE(mapValue != NULL);
//        ASSERT_TRUE(mapValue == myValue);
//        ASSERT_TRUE(strKey == str);

    }

TEST_F(AnalyticEventTest, testRequestEventCreation) {
    EventManager manager{store};

    auto event = manager.newRequestEvent(1, 20, Connectivity::Facade::getInstance().startTrip(), validator);
    auto json = event->generateJSONObject();
    ASSERT_EQ("MobileRequest",(*json)["eventType"].as_string());
    ASSERT_EQ(20,(*json)["timeSinceLoad"].as_float());
    ASSERT_EQ(1,(*json)["timestamp"].as_float());
}

TEST_F(AnalyticEventTest, testNetworkErrorEventCreation) {
    EventManager manager{store};
    auto payload = Connectivity::Facade::getInstance().newPayload();
    auto event = manager.newNetworkErrorEvent(1, 20, nullptr, nullptr, std::move(payload), validator);
    auto json = event->generateJSONObject();
    ASSERT_EQ("MobileRequestError",(*json)["eventType"].as_string());
    ASSERT_EQ(20,(*json)["timeSinceLoad"].as_float());
    ASSERT_EQ(1,(*json)["timestamp"].as_float());
}

    TEST_F(AnalyticEventTest, testUserActionEventCreation) {

        EventManager manager{store};
        auto event = manager.newUserActionEvent(1, 20, validator);
        auto json = event->generateJSONObject();
        ASSERT_EQ(__kNRMA_RET_mobileUserAction,(*json)["eventType"].as_string());
        ASSERT_EQ(20,(*json)["timeSinceLoad"].as_float());
        ASSERT_EQ(1,(*json)["timestamp"].as_float());


        std::stringstream ss;
        ss << *event;

        auto reEvent = manager.newEvent(ss);

        ASSERT_EQ(*event,*reEvent);
    }

    TEST_F(AnalyticEventTest, testSessionAnalyticEventCreation){
        EventManager manager{store};
        auto event = manager.newSessionAnalyticEvent(1,20,validator);
        auto json = event->generateJSONObject();
        ASSERT_EQ("Session",(*json)["category"].as_string());
        ASSERT_EQ(20,(*json)["timeSinceLoad"].as_float());
        ASSERT_EQ("Mobile",(*json)["eventType"].as_string());
        ASSERT_EQ(1,(*json)["timestamp"].as_float());
    }

    TEST_F(AnalyticEventTest, testSessionAnalyticEventSerialization) {
        EventManager manager{store};
        auto event = manager.newSessionAnalyticEvent(1,20,validator);

        std::stringstream ss;
        ss << *event;

        auto reEvent = manager.newEvent(ss);

        ASSERT_EQ(*event,*reEvent);

    }
    TEST_F(AnalyticEventTest, testCustomMobileEventCreation) {

        auto validator = AttributeValidator([](const char *) { return true; },
                                            [](const char *) { return true; },
                                            [](const char *) { return true; });
        std::remove("pewpew.txt");
        PersistentStore<std::string, AnalyticEvent> store("pewpew.txt", "", &EventManager::newEvent);
        EventManager eventManager(store);
        auto event = eventManager.newCustomMobileEvent("TestEvent",
                                                       1234567890,
                                                       1234567890,
                                                       validator);
        ASSERT_TRUE(event != nullptr);
        ASSERT_EQ((event->getCategory()), std::string("Custom"));
    }

    TEST_F(AnalyticEventTest, testCustomEvent) {
        auto validator = (AttributeValidator([](const char *) { return true; }, [](const char *) { return true; }, [](const char *) { return true; }));
        std::remove("pewpew.txt");
        PersistentStore<std::string, AnalyticEvent> store("pewpew.txt", "", &EventManager::newEvent);
        EventManager eventManager(store);
        auto event = eventManager.newCustomEvent("TestEvent", 1234567890,1234567890,validator);
        event->addAttribute("blah","blah");
        event->addAttribute("asdf", 100.0f);
        event->addAttribute("bam", 1);
        ASSERT_TRUE(event != nullptr);
        ASSERT_EQ(event->getEventType(),std::string("TestEvent"));

        auto json = event->generateJSONObject();


        auto value = (*json)["eventType"].as_string();
        ASSERT_TRUE(value == "TestEvent");
        std::stringstream ss;

        ss << (*event);

        auto event2 = eventManager.newEvent(ss);


        ASSERT_TRUE(*event == *event2);
        std::remove("pewpew.txt");

    }

    TEST_F(AnalyticEventTest, testBoolAttributes) {
        auto validator = AttributeValidator([](const char *) { return true; },
                                            [](const char *) { return true; },
                                            [](const char *) { return true; });
        std::remove("pewpew.txt");
        PersistentStore<std::string, AnalyticEvent> store("pewpew.txt", "", &EventManager::newEvent);
        EventManager eventManager(store);
        auto event = eventManager.newCustomMobileEvent("TestEvent",
                                                       1234567890,
                                                       1234567890,
                                                       validator);
        event->addAttribute("thisIsTrue", true);
        event->addAttribute("thisIsFalse", false);

        ASSERT_TRUE(event != nullptr);
        ASSERT_EQ((event->getCategory()), std::string("Custom"));

        auto json = event->generateJSONObject();

        ASSERT_TRUE((*json)["thisIsTrue"].as_bool());
        ASSERT_TRUE(!((*json)["thisIsFalse"].as_bool()));



    }

    TEST(AnalyticEvent, testInteractionEvent) {

        auto validator = (AttributeValidator([](const char *) { return true; },
                                             [](const char *) { return true; },
                                             [](const char *) { return true; }));
        std::remove("pewpew.txt");
        PersistentStore<std::string, AnalyticEvent> store("pewpew.txt", "", &EventManager::newEvent);
        EventManager eventManager(store);
        auto event = eventManager.newInteractionAnalyticEvent("TestEvent",
                                                              1234567890,
                                                              1234567890,
                                                              validator);
        event->addAttribute("test1", "test1");
        event->addAttribute("test2", 1.223f);
        event->addAttribute("test3", (double)-102222312345);

        ASSERT_TRUE(event != nullptr);
        ASSERT_EQ((event->getCategory()), std::string("Interaction"));

        auto json = event->generateJSONObject();

        ASSERT_TRUE((*json)["name"].as_string() == "TestEvent");
        ASSERT_TRUE((*json)["test1"].as_string() == "test1");
        ASSERT_TRUE((*json)["test2"].as_float() == 1.223f);
        ASSERT_EQ(static_cast<double>(-102222312345), (*json)["test3"].as_float());
    }


    TEST(AnalyticEvent, testEventManager) {

        auto validator = (AttributeValidator([](const char *) { return true; },
                                             [](const char *) { return true; },
                                             [](const char *) { return true; }));
        std::remove("pewpew.txt");
        PersistentStore<std::string, AnalyticEvent> store("pewpew.txt", "", &EventManager::newEvent);

        EventManager eventManager(store);
        auto event = eventManager.newCustomMobileEvent("custom",
                                                       1234567890,
                                                       1234567890,
                                                       validator);

        eventManager.addEvent(event);

        auto jsonArray = eventManager.toJSON();

        ASSERT_EQ(1, jsonArray->size());

        eventManager.empty();

        jsonArray = eventManager.toJSON();

        ASSERT_EQ(0, jsonArray->size());
    }

    TEST(AnalyticEvent, testEventBadInput) {

        //validator always returns false
        //nothing is valid.
        auto validator = (AttributeValidator([](const char *) { return false; },
                                             [](const char *) { return true; },
                                             [](const char *) { return true; }));
        std::remove("pewpew.txt");
        PersistentStore<std::string, AnalyticEvent> store("pewpew.txt", "", &EventManager::newEvent);
        EventManager eventManager(store);
        auto event = eventManager.newCustomMobileEvent("custom",
                                                       1234567890,
                                                       1234567890,
                                                       validator);
        ASSERT_FALSE(event->addAttribute("hello", "world"));

        //assert we do not see the bad attribute into the object.
        ASSERT_EQ(NRJSON::NIL, (*(event->generateJSONObject()))["hello"].type());

    }

    TEST(AnalyticEvent, testThreading) {
        auto validator = (AttributeValidator([](const char *) { return false; },
                                             [](const char *) { return true; },
                                             [](const char *) { return true; }));
        std::remove("pewpew.txt");
        PersistentStore<std::string, AnalyticEvent> store("pewpew.txt", "", &EventManager::newEvent);
        EventManager eventManager(store);

        std::thread th1{[&eventManager, &validator]() {
            for (int i = 0; i < 10; i++) {

                char buf[20];
                snprintf(buf, 20, "blah%d", i);
                std::string str{buf};
                auto event = eventManager.newCustomMobileEvent(str.c_str(),
                                                               1234567890,
                                                               1234567890,
                                                               validator);
                eventManager.addEvent(event);
                std::this_thread::sleep_for(std::chrono::milliseconds(10));
            }
        }};
        std::thread th2{[&eventManager, &validator]() {
            for (int i = 10; i < 20; i++) {
                char buf[20];
                snprintf(buf, 20, "blah%d", i);
                std::string str{buf};
                auto event = eventManager.newCustomMobileEvent(str.c_str(),
                                                               1234567890,
                                                               1234567890,
                                                               validator);
                eventManager.addEvent(event);
                std::this_thread::sleep_for(std::chrono::milliseconds(10));
            }
        }};

        std::thread th3{[&eventManager, &validator]() {
            for (int i = 20; i < 30; i++) {
                char buf[20];
                snprintf(buf, 20, "blah%d", i);
                std::string str{buf};
                auto event = eventManager.newCustomMobileEvent(str.c_str(),
                                                               1234567890,
                                                               1234567890,
                                                               validator);
                eventManager.addEvent(event);
                std::this_thread::sleep_for(std::chrono::milliseconds(10));
            }
        }};
        std::thread th4{[&eventManager, &validator]() {
            for (int i = 30; i < 40; i++) {
                char buf[20];
                snprintf(buf, 20, "blah%d", i);
                std::string str{buf};
                auto event = eventManager.newCustomMobileEvent(str.c_str(),
                                                               1234567890,
                                                               1234567890,
                                                               validator);
                eventManager.addEvent(event);
                std::this_thread::sleep_for(std::chrono::milliseconds(10));
            }
        }};
        std::thread th5{[&eventManager, &validator]() {
            for (int i = 40; i < 50; i++) {
                char buf[20];
                snprintf(buf, 20, "blah%d", i);
                std::string str{buf};
                auto event = eventManager.newCustomMobileEvent(str.c_str(),
                                                               1234567890,
                                                               1234567890,
                                                               validator);
                eventManager.addEvent(event);
                std::this_thread::sleep_for(std::chrono::milliseconds(10));
            }
        }};
        std::thread th6{[&eventManager, &validator]() {
            for (int i = 50; i < 60; i++) {
                char buf[20];
                snprintf(buf, 20, "blah%d", i);
                std::string str{buf};
                auto event = eventManager.newCustomMobileEvent(str.c_str(),
                                                               1234567890,
                                                               1234567890,
                                                               validator);
                eventManager.addEvent(event);
                std::this_thread::sleep_for(std::chrono::milliseconds(10));
            }
        }};

        th1.join();
        th2.join();
        th3.join();
        th4.join();
        th5.join();
        th6.join();

        auto json = eventManager.toJSON();

        ASSERT_TRUE(json->size() == 60);


    };

    TEST(AnalyticsEvent, testBasicSerialization) {
        auto validator = (AttributeValidator([](const char *) { return true; },
                                             [](const char *) { return true; },
                                             [](const char *) { return true; }));
        std::remove("pewpew.txt");
        PersistentStore<std::string, AnalyticEvent> store("pewpew.txt", "", &EventManager::newEvent);
        EventManager eventmanager(store);
        std::stringstream ss;
        auto event = EventManager::newCustomMobileEvent("nam e",
                                                        1234567890,
                                                        1234567890,
                                                        validator);


        ss << *event;


        auto newEvent = EventManager::newEvent(ss);

        ASSERT_TRUE(*event == *newEvent);

    }

    TEST(AnalyticEvent, testDupStore) {

        auto validator = (AttributeValidator([](const char *) { return true; },
                                             [](const char *) { return true; },
                                             [](const char *) { return true; }));
        std::remove("pewpew.txt");
        PersistentStore<std::string, AnalyticEvent> store("pewpew.txt", "", &EventManager::newEvent);
        EventManager eventManager(store);
        std::stringstream ss;
        auto event = eventManager.newCustomMobileEvent("nam e",
                                                       1234567890,
                                                       1234567890,
                                                       validator);

        event->addAttribute("bla h", "b lah");
        event->addAttribute("pe w", "pe w");
        event->addAttribute("12 345", 12345);

        eventManager.addEvent(event);

        auto event2 = eventManager.newCustomMobileEvent("nam e",
                                                        123,
                                                        1234,
                                                        validator);

        event2->addAttribute("asdf","asdf");

        eventManager.addEvent(event2);

        //to test the persistent store there must be a beat to allow the workQueue to catch up.
        store.synchronize();

        auto map = store.load();

        ASSERT_EQ(2,map.size());
    }

    TEST(AnalyticEvent, testFullSerialization) {
        auto validator = (AttributeValidator([](const char *) { return true; },
                                             [](const char *) { return true; },
                                             [](const char *) { return true; }));
        std::remove("pewpew.txt");
        PersistentStore<std::string, AnalyticEvent> store("pewpew.txt", "", &EventManager::newEvent);
        EventManager eventManager(store);
        std::stringstream ss;
        auto event = eventManager.newCustomMobileEvent("nam e",
                                                       1234567890,
                                                       1234567890,
                                                       validator);
        event->addAttribute("bla h", "b lah");
        event->addAttribute("pe w", "pe w");
        event->addAttribute("12 345", 12345);
        ss << *event;

        auto newEvent = eventManager.newEvent(ss);

        auto event2 = eventManager.newCustomMobileEvent("nam e",
                                                        123,
                                                        1234,
                                                        validator);
        event2->addAttribute("asdf","asdf");
        std::stringstream ss2;
        ss2 << *event2;
        auto newEvent2 = eventManager.newEvent(ss2);

        ASSERT_TRUE(*event == *newEvent);
        ASSERT_FALSE(*newEvent == *newEvent2);
    }

    TEST(AnalyticEvent, testSerializationWithTabs) {
        auto validator = (AttributeValidator([](const char *) { return true; },
                                             [](const char *) { return true; },
                                             [](const char *) { return true; }));



        PersistentStore<std::string, AnalyticEvent> store("pewpew.txt", "", &EventManager::newEvent);
        EventManager eventManager(store);
        std::stringstream ss;
        auto event = eventManager.newCustomMobileEvent("nam\te",
                                                       1234567890,
                                                       1234567890,
                                                       validator);

        event->addAttribute("bla\th", "blah");
        event->addAttribute("pe\tw", "pe w");
        event->addAttribute("12\t345", 12345);

        ss << *event;

        ASSERT_NO_THROW(eventManager.newEvent(ss));

    }


TEST_F(AnalyticEventTest, testDTIntrinsics) {
    auto validator = (AttributeValidator([](const char *) { return true; },
                                         [](const char *) { return true; },
                                         [](const char *) { return true; }));



    PersistentStore<std::string, AnalyticEvent> store("pewpew.txt", "", &EventManager::newEvent);
    EventManager eventManager(store);
    std::stringstream ss;

    auto payload_t = Connectivity::Facade::getInstance().startTrip();

    auto payload = *payload_t;

    auto event = eventManager.newRequestEvent(0, 1, std::move(payload_t), validator);

    event->addAttribute("bla\th", "blah");
    event->addAttribute("pe\tw", "pe w");
    event->addAttribute("12\t345", 12345);

    ss << *event;

    auto streamEvent = eventManager.newEvent(ss);

    ASSERT_TRUE(event->equal(*streamEvent));

    auto json = event->generateJSONObject();

    ASSERT_EQ(payload.getId(), (*json)["guid"].as_string());
    ASSERT_EQ(payload.getTraceId(), (*json)["traceId"].as_string());
    ASSERT_EQ(NRJSON::ValueType::NIL, (*json)["nr.parentId"].type());
}

TEST_F(AnalyticEventTest, testRequestErrorIntrinsics) {
    auto validator = (AttributeValidator([](const char *) { return true; },
                                         [](const char *) { return true; },
                                         [](const char *) { return true; }));



    PersistentStore<std::string, AnalyticEvent> store("pewpew.txt", "", &EventManager::newEvent);
    EventManager eventManager(store);
    std::stringstream ss;

    auto payload_t = Connectivity::Facade::getInstance().startTrip();

    auto payload = *payload_t;

    auto event = eventManager.newNetworkErrorEvent(0, 1, "blahblahblah=", "appdatatHeader", std::move(payload_t), validator);

    ss << *event;

    auto streamEvent = eventManager.newEvent(ss);

    ASSERT_TRUE(event->equal(*streamEvent));

    auto json = event->generateJSONObject();

    ASSERT_EQ(payload.getId(), (*json)["guid"].as_string());
    ASSERT_EQ(payload.getTraceId(), (*json)["traceId"].as_string());
    ASSERT_EQ(NRJSON::ValueType::NIL, (*json)["nr.parentId"].type());
}

TEST_F(AnalyticEventTest, testRequestsIntrinsics) {
    auto validator = (AttributeValidator([](const char *) { return true; },
                                         [](const char *) { return true; },
                                         [](const char *) { return true; }));



    PersistentStore<std::string, AnalyticEvent> store("pewpew.txt", "", &EventManager::newEvent);
    EventManager eventManager(store);
    std::stringstream ss;

    auto payload_t = Connectivity::Facade::getInstance().startTrip();

    auto payload = *payload_t;

    auto event = eventManager.newRequestEvent(0, 1, std::move(payload_t), validator);

    ss << *event;

    auto streamEvent = eventManager.newEvent(ss);

    ASSERT_TRUE(event->equal(*streamEvent));

    auto json = event->generateJSONObject();

    ASSERT_EQ(payload.getId(), (*json)["guid"].as_string());
    ASSERT_EQ(payload.getTraceId(), (*json)["traceId"].as_string());
    ASSERT_EQ(payload.getParentId(), (*json)["nr.parentId"].as_string());
}
}

