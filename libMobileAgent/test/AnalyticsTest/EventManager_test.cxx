#include <gmock/gmock.h>
#include <Analytics/EventManager.hpp>
#include <string>
#include <Analytics/EventBufferConfig.hpp>

using ::testing::Eq;
using ::testing::_;
using ::testing::Test;
using testing::_;
using testing::AnyNumber;
using testing::AtLeast;
using testing::AtMost;
using testing::Between;
using testing::Cardinality;
using testing::CardinalityInterface;
using testing::ContainsRegex;
using testing::Const;
using testing::DoAll;
using testing::DoDefault;
using testing::Eq;
using testing::Expectation;
using testing::ExpectationSet;
using testing::GMOCK_FLAG(verbose);
using testing::Gt;
using testing::InSequence;
using testing::Invoke;
using testing::InvokeWithoutArgs;
using testing::IsSubstring;
using testing::Lt;
using testing::Message;
using testing::Mock;
using testing::NaggyMock;
using testing::Ne;
using testing::Return;
using testing::Sequence;
using testing::SetArgPointee;
using testing::internal::ExpectationTester;
using testing::internal::FormatFileLocation;
using testing::internal::kErrorVerbosity;
using testing::internal::kInfoVerbosity;
using testing::internal::kWarningVerbosity;
using testing::internal::linked_ptr;
using testing::internal::string;
namespace NewRelic {

class EventManagerTest : public ::testing::Test {
public:
    const char* storeFilename = "pewpew.txt";
    unsigned long long epoch_time_ms;
    std::string sessionDataPathString;
    const char* sessionDataPath;
    PersistentStore<std::string, AnalyticEvent> store;
    AttributeValidator validator = AttributeValidator([](const char* name) { return strlen(name) < 10; },
                                                      [](const char* value) { return strlen(value) < 10; },
                                                      [](const char* eventType) { return true; });
public:
    EventManagerTest() : Test(),
                         epoch_time_ms((unsigned long long) std::chrono::duration_cast<std::chrono::milliseconds>(
                                 std::chrono::system_clock().now().time_since_epoch()).count()),
                         sessionDataPathString(""), // std::to_string(epoch_time_ms)),
                         sessionDataPath(sessionDataPathString.c_str()),
                         store(PersistentStore<std::string, AnalyticEvent>(storeFilename, sessionDataPath,
                                                                           &EventManager::newEvent)) {
    }

protected:
    virtual void SetUp() {
    }

    virtual void TearDown() {
        EventBufferConfig::getInstance().setMaxEventBufferTime(EventBufferConfig::kMaxEventBufferTimeSecDefault);
        EventBufferConfig::getInstance().setMaxEventBufferSize(EventBufferConfig::kMaxEventBufferSizeDefault);
        remove(store.getFullStorePath());
        remove(sessionDataPath);
    }
};

class MockEventManager : public EventManager {
public:
    MockEventManager(PersistentStore<std::string, AnalyticEvent>& store) : EventManager(store) {
    }

    MOCK_METHOD0(getRemovalIndex, int());
};

TEST_F(EventManagerTest, testPersistantBuffer) {
    EventManager manager{store};

    manager.setMaxBufferSize(1);

    EventManager secondManager{store};

    // add two events -- we should only get 1 because our settings should persist
    auto event1 = manager.newCustomMobileEvent("custom1", epoch_time_ms, 1, validator);
    auto event2 = manager.newCustomMobileEvent("custom2", epoch_time_ms, 1, validator);
    secondManager.addEvent(event1);
    secondManager.addEvent(event2);

    auto json = secondManager.toJSON();
    ASSERT_EQ(1, json->size());
}

TEST_F(EventManagerTest, testAgedEvents) {
    EventManager manager{store};
    long long epoch_time_ms = std::chrono::duration_cast<std::chrono::milliseconds>(
            std::chrono::system_clock().now().time_since_epoch()).count();
    ASSERT_FALSE(manager.didReachMaxQueueTime(epoch_time_ms));

    auto event = manager.newCustomMobileEvent("custom", epoch_time_ms, 1, validator);

    manager.addEvent(event);
    ASSERT_TRUE(manager.didReachMaxQueueTime(
            INT64_MAX));   // int max == far in the future... all the events have aged out.
}

TEST_F(EventManagerTest, testSetMaxEventBufferTime) {
    EventManager manager{store};

    //nothing will age out!
    manager.setMaxBufferTime(UINT32_MAX);

    auto event = manager.newCustomMobileEvent("custom", epoch_time_ms - 1000, 1, validator);

    manager.addEvent(event);
    ASSERT_FALSE(manager.didReachMaxQueueTime(epoch_time_ms));

    manager.setMaxBufferTime(1);
    ASSERT_TRUE(manager.didReachMaxQueueTime(epoch_time_ms));
}

TEST_F(EventManagerTest, testMaxQueueSize) {
    EventManager manager{store};

    manager.setMaxBufferSize(1);

    auto event = manager.newCustomMobileEvent("custom", epoch_time_ms - 1000, 1, validator);
    manager.addEvent(event);

    event = manager.newCustomMobileEvent("custom 2", epoch_time_ms, 1, validator);
    manager.addEvent(event);

    auto json = manager.toJSON();

    ASSERT_EQ(1, json->size());
    manager.setMaxBufferSize(2);

    event = manager.newCustomMobileEvent("3", epoch_time_ms, 1, validator);
    manager.addEvent(event);

    json = manager.toJSON();
    ASSERT_EQ(2, json->size());
}

TEST_F(EventManagerTest, testGetRemoveIndexFromQueue) {
    MockEventManager manager{store};

    EXPECT_CALL(manager, getRemovalIndex())
            .WillOnce(Return(0)); //this will remove the 1 item in the event queue

    manager.setMaxBufferSize(1);

    auto event = manager.newCustomMobileEvent("custom", epoch_time_ms - 1000, 1, validator);
    manager.addEvent(event);

    event = manager.newCustomMobileEvent("custom 2", epoch_time_ms, 1, validator);
    manager.addEvent(event);

    auto json = manager.toJSON();
    ASSERT_EQ(1, json->size());
    ASSERT_EQ(((*json)[0]["name"]).as_string(), "custom 2");
}

TEST_F(EventManagerTest, testGetRemoveIndexDropNew) {
    MockEventManager manager{store};

    manager.setMaxBufferSize(1);

    EXPECT_CALL(manager, getRemovalIndex())
            .WillOnce(Return(100)); //this will result in the new event being dropped.

    auto event = manager.newCustomMobileEvent("custom", epoch_time_ms - 1000, 1, validator);
    manager.addEvent(event);

    event = manager.newCustomMobileEvent("custom 2", epoch_time_ms, 1, validator);
    manager.addEvent(event);

    auto json = manager.toJSON();
    ASSERT_EQ(1, json->size());
    ASSERT_EQ(((*json)[0]["name"]).as_string(), "custom");
}

TEST_F(EventManagerTest, testZeroQueueSize) {
    EventManager manager{store};

    manager.setMaxBufferSize(0);

    auto event = manager.newCustomMobileEvent("custom", epoch_time_ms - 1000, 1, validator);
    ASSERT_NO_THROW(manager.addEvent(event));

    auto json = manager.toJSON();
    ASSERT_EQ(0, json->size());
}

TEST_F(EventManagerTest, testDuplicationStore) {
    PersistentStore<std::string, AnalyticEvent> store(storeFilename, sessionDataPath,
                                                      &EventManager::newEvent);

    EventManager manager{store};
    auto event = manager.newCustomMobileEvent("blah", epoch_time_ms, epoch_time_ms / 1000, validator);
    manager.addEvent(event);

    store.synchronize();

    auto duplicatedEvents = store.load();
    ASSERT_EQ(1, duplicatedEvents.size());

    auto storedEvent = (duplicatedEvents.begin()->second);
    ASSERT_EQ(*event, *storedEvent);
}

TEST_F(EventManagerTest, testJSONAsValue) {
    auto validator = AttributeValidator([](const char* name) { return true; },
                                                            [](const char* value) { return true; },
                                                            [](const char* eventType) { return true; });

    EventManager manager{store};
    NRJSON::JsonObject object;
    object["hello"] = "\"world\"";

    std::stringstream s;
    s << object;
    ASSERT_EQ("{\n\"hello\": \"\\\"world\\\"\"\n}", s.str());

    NRJSON::JsonArray array{};
    array.push_back(object);

    std::stringstream jarrStream;
    jarrStream << array;
    ASSERT_EQ("[\n{\n\"hello\": \"\\\"world\\\"\"\n}\n]", jarrStream.str());

    NRJSON::JsonValue value{"\""};
    std::stringstream jvalStream;
    jvalStream << value;
    ASSERT_EQ("\"\\\"\"", jvalStream.str());

    auto event = manager.newCustomMobileEvent("blah", epoch_time_ms, epoch_time_ms / 1000, validator);
    ASSERT_TRUE(event->addAttribute("data", "{\"in_id\":16853,\"acc_id\":1}"));

    manager.addEvent(event);

    auto json = manager.toJSON();
    ASSERT_EQ(1, (*json).size());

}

TEST_F(EventManagerTest, testEscapeCharacters) {
    auto validator = AttributeValidator([](const char* name) { return true; },
                                                            [](const char* value) { return true; },
                                                            [](const char* eventType) { return true; });

    EventManager manager{store};
    auto event = manager.newCustomMobileEvent("hello\r\n\b\a\f\v\t", 0, 1, validator);
    event->addAttribute("blah\t\b\a\n\f\v\t", "blah");
    event->addAttribute("blah\\t\\b\\a\\n\\f\\v\\t", "blah\t\b\a\n\f\v\t");
    auto json = std::dynamic_pointer_cast<CustomMobileEvent>(event)->generateJSONObject();

    ASSERT_TRUE((*json)["name"].as_string().compare("hello\\r\\n\\b\\a\\f\\v\\t") == 0);
    ASSERT_TRUE((*json)["blah\\t\\b\\a\\n\\f\\v\\t"].as_string().compare("blah\\t\\b\\a\\n\\f\\v\\t") == 0);
}


TEST_F(EventManagerTest, testBadSerializedEvent) {
    auto validator = AttributeValidator([](const char* name) { return true; },
                                                            [](const char* value) { return true; },
                                                            [](const char* eventType) { return true; });

    EventManager manager{store};

    std::stringstream strs;
    strs << "ta.com/graphql\tresponseTime\t1\t0\t0.374951904296875\tstatusCode\t1\t2\t200\t";

    ASSERT_NO_THROW(manager.newEvent(strs));

    std::stringstream strs2;
    strs << "\t";

    ASSERT_THROW(manager.newEvent(strs2), std::runtime_error);
}
} // namespace NewRelic

