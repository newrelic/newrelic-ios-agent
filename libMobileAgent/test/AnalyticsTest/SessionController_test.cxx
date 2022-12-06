#include <Analytics/Stores/PersistentStore.hpp>
#include <gmock/gmock.h>
#include <Analytics/SessionAttributeManager.hpp>

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
    class SessionAttributesTest : public ::testing::Test {
    public:
        unsigned long long epoch_time_ms;
        const char *storeName = "pewpew.txt";
        AttributeValidator validator = AttributeValidator([](const char *name) { return strlen(name) < 10; },
                                                          [](const char *value) { return strlen(value) < 10; },
                                                          [](const char *eventType) {return true;});


    protected:
        SessionAttributesTest() : Test(),
                                  epoch_time_ms(
                                          (unsigned long long) std::chrono::duration_cast<std::chrono::milliseconds>(
                                                  std::chrono::system_clock().now().time_since_epoch()).count()) {
        }

        virtual void SetUp() {
            remove(storeName);
        }

        virtual void TearDown() {
            remove(storeName);
        }
    };


    template<typename K, typename T>
    class MockPersistentStore : public PersistentStore<K, T> {
    public:
        MockPersistentStore(const char *sharedPath, AttributeValidator &validator) : PersistentStore<K, T>(
                "blah.txt", "", &Value::createValue) {
        }

        virtual ~MockPersistentStore() { }

        MOCK_METHOD2_T(store, void(K
                name, std::shared_ptr<T>
                value));

        MOCK_METHOD1_T(remove, void(K
                name));

        MOCK_METHOD0_T(load, std::map<K, std::shared_ptr<T>>(void));
    };


    TEST(SessionAttributes, testAddFloat) {
        AttributeValidator validator = AttributeValidator(
                [](const char *name) { return strlen(name) < 10; },
                [](const char *value) { return strlen(value) < 10; },
                [](const char *eventType) { return true; });

        MockPersistentStore<std::string, BaseValue> persistentStore{"", validator};
        std::remove("pewpew.txt");
        PersistentStore<std::string, BaseValue> store2{"pewpew.txt", "", &Value::createValue};
        SessionAttributeManager attributeManager(persistentStore, store2, validator);
        EXPECT_CALL(persistentStore, store(_, _))
                .Times(2);

        EXPECT_CALL(persistentStore, remove(_))
                .Times(1);
        ASSERT_TRUE(attributeManager.addSessionAttribute("hello", 0.0f));
        ASSERT_TRUE(attributeManager.addSessionAttribute("hello", 1.0f, true));
        ASSERT_TRUE(attributeManager.addSessionAttribute("hello", 2.0f)); //should call persistent store again.
        ASSERT_TRUE(attributeManager.addSessionAttribute("hello", 3.0f, false));
        ASSERT_TRUE(attributeManager.addSessionAttribute("hello", 2.0f));
        ASSERT_TRUE((*attributeManager.generateJSONObject())["hello"].as_float() == 2.0f);
    }

    TEST(SessionAttributes, testAddString) {
        AttributeValidator validator = AttributeValidator(
                [](const char *name) { return strlen(name) < 10; },
                [](const char *value) { return strlen(value) < 10; },
                [](const char *eventType) { return true; });
        auto validatorPtr = validator;
        MockPersistentStore<std::string, BaseValue> persistentStore{"", validator};
        std::remove("pewpew.txt");
        PersistentStore<std::string, BaseValue> store2{"pewpew.txt", "", &Value::createValue};

        SessionAttributeManager attributeManager(persistentStore, store2, validatorPtr);
        EXPECT_CALL((persistentStore), store(_, _))
                .Times(2);

        EXPECT_CALL((persistentStore), remove(_))
                .Times(1);
        ASSERT_TRUE(attributeManager.addSessionAttribute("hello", "world"));
        ASSERT_TRUE(attributeManager.addSessionAttribute("hello", "blah", true));
        ASSERT_TRUE(attributeManager.addSessionAttribute("hello", "one")); //should call persistent store again.
        ASSERT_TRUE(attributeManager.addSessionAttribute("hello", "two", false));
        ASSERT_TRUE(attributeManager.addSessionAttribute("hello", "world"));
        ASSERT_TRUE((*attributeManager.generateJSONObject())["hello"].as_string() == "world");
    }

    TEST(SessionAttributes, testPersistentStoreRetrieval) {
        AttributeValidator validator = AttributeValidator(
                [](const char *name) { return strlen(name) < 10; },
                [](const char *value) { return strlen(value) < 10; },
                [](const char *) { return true; });
        auto validatorPtr = validator;
        MockPersistentStore<std::string, BaseValue> persistentStore{"", validatorPtr};
        auto attrib = Attribute<double>::createAttribute(
                "hello",
                validator.getNameValidator(),
                10,
                [](double blah) { return true; });
        auto attrib2 = Attribute<const char *>::createAttribute(
                "blah",
                validator.getNameValidator(),
                "world",
                validator.getValueValidator());

        std::map<std::string, std::shared_ptr<BaseValue>> map;
        map["hello"] = attrib->getValue();
        map["blah"] = attrib2->getValue();

        EXPECT_CALL((persistentStore), load())
                .WillOnce(Return(map));
        //this gets called when the persistent attributes are pushed to the in memory std::map.
        EXPECT_CALL((persistentStore), store(_, _))
                .Times(2);
        std::remove("pewpew.txt");
        PersistentStore<std::string, BaseValue> store2{"pewpew.txt", "", &Value::createValue};
        SessionAttributeManager attributeManager(persistentStore, store2, validatorPtr);

        auto json = attributeManager.generateJSONObject();

        ASSERT_TRUE((*attributeManager.generateJSONObject())["hello"].as_float() == 10);
        ASSERT_TRUE((*attributeManager.generateJSONObject())["blah"].as_string() == "world");
    }

    TEST(SessionAttributes, testRemoveAttributes) {
        AttributeValidator validator = AttributeValidator(
                [](const char *name) { return strlen(name) < 10; },
                [](const char *value) { return strlen(value) < 10; },
                [](const char *) { return true; });
        auto validatorPtr = validator;
        MockPersistentStore<std::string, BaseValue> persistentStore{"", validatorPtr};

        EXPECT_CALL((persistentStore), remove(_))
                .Times(1);
        EXPECT_CALL((persistentStore), store(_, _))
                .Times(1);
        std::remove("pewpew.txt");
        PersistentStore<std::string, BaseValue> store2{"pewpew.txt", "", &Value::createValue};
        SessionAttributeManager attributeManager(persistentStore, store2, validatorPtr);

        attributeManager.addSessionAttribute("hello", "world");
        attributeManager.addSessionAttribute("number", 1.0f, true);

        attributeManager.removeSessionAttribute("hello");
        attributeManager.removeSessionAttribute("number");

        auto json = attributeManager.generateJSONObject();

        ASSERT_TRUE(json->size() == 0);
    }

    TEST(SessionAttributes, testSpaceyKeyCollisions) {

        AttributeValidator validator = AttributeValidator(
                [](const char *name) { return true;},
                [](const char *value) { return true;},
                [](const char *) { return true;});
        auto validatorPtr = (validator);
        MockPersistentStore<std::string, BaseValue> persistentStore{"", validatorPtr};
        std::remove("pewpew.txt");
        PersistentStore<std::string, BaseValue> store2{"pewpew.txt", "", &Value::createValue};
        SessionAttributeManager attributeManager(persistentStore, store2, validatorPtr);


        ASSERT_TRUE(attributeManager.addSessionAttribute("Mr. T", "pew"));
        ASSERT_TRUE(attributeManager.addSessionAttribute("Mr. Trello", "asdfasdf"));


        store2.synchronize();

        auto map = store2.load();

        ASSERT_EQ(2,map.size());

    }

    TEST(SessionAttributes, testSessionAttributeLimit) {
        AttributeValidator validator = AttributeValidator(
                [](const char *name) { return strlen(name) < 10; },
                [](const char *value) { return strlen(value) < 10; },
                [](const char *) { return true;});
        auto validatorPtr = (validator);
        MockPersistentStore<std::string, BaseValue> persistentStore{"", validatorPtr};
        std::remove("pewpew.txt");
        PersistentStore<std::string, BaseValue> store2{"pewpew.txt", "", &Value::createValue};
        SessionAttributeManager attributeManager(persistentStore, store2, validatorPtr);
        for (int i = 0; i < SessionAttributeManager::kAttributeLimit; i++) {
            char buf[20];
            snprintf(buf, 20, "%d", i);
            ASSERT_TRUE(attributeManager.addSessionAttribute(buf, (double) i));
        }

        ASSERT_FALSE(attributeManager.addSessionAttribute("Hello", "world"));
    }

    TEST(SessionAttributes, testSessionAttributeLimitWithPersistent) {
        AttributeValidator validator = AttributeValidator(
                [](const char *name) { return strlen(name) < 10; },
                [](const char *value) { return strlen(value) < 10; },
                [](const char *) { return true;});
        auto validatorPtr = validator;
        MockPersistentStore<std::string, BaseValue> persistentStore{"", validatorPtr};
        EXPECT_CALL((persistentStore), store(_, _))
                .Times(SessionAttributeManager::kAttributeLimit);
        std::remove("pewpew.txt");
        PersistentStore<std::string, BaseValue> store2{"pewpew.txt", "", &Value::createValue};
        SessionAttributeManager attributeManager(persistentStore, store2, validatorPtr);
        for (int i = 0; i < SessionAttributeManager::kAttributeLimit; i++) {
            char buf[20];
            snprintf(buf, 20, "%d", i);
            ASSERT_TRUE(attributeManager.addSessionAttribute(buf, (double) i, true));
        }

        ASSERT_FALSE(attributeManager.addSessionAttribute("Hello", "world"));
    }

    TEST(SessionAttributes, testValidationFailure) {
        AttributeValidator validator = AttributeValidator(
                [](const char *name) { return strlen(name) < 10; },
                [](const char *value) { return strlen(value) < 10; },
                [](const char *) { return true;});
        auto validatorPtr = validator;
        MockPersistentStore<std::string, BaseValue> persistentStore{"", validatorPtr};
        std::remove("pewpew.txt");
        PersistentStore<std::string, BaseValue> store2{"pewpew.txt", "", &Value::createValue};
        SessionAttributeManager attributeManager(persistentStore, store2, validatorPtr);

        ASSERT_FALSE(attributeManager.addSessionAttribute("123456789011", "world")); //fails attributeValidator for Name
        ASSERT_FALSE(attributeManager.addSessionAttribute("blah", "123456789011")); //fails attributeValidator for Value
        ASSERT_FALSE(attributeManager.addSessionAttribute("123456789011", 10.0f)); //fails attributeValidator for Value
        ASSERT_FALSE(
                attributeManager.addSessionAttribute("123456789011", 10.0f, true)); //fails attributeValidator for Value
        ASSERT_FALSE(attributeManager.addSessionAttribute("123456789011", "world",
                                                          true)); //fails attributeValidator for Name
        ASSERT_FALSE(attributeManager.addSessionAttribute("blah", "123456789011",
                                                          true)); //fails attributeValidator for Value
    }

    TEST(SessionAttributes, testPrivateAttributes) {
        AttributeValidator validator = AttributeValidator(
                [](const char *name) { return strlen(name) < 10; },
                [](const char *value) { return strlen(value) < 10; },
                [](const char *) { return true;});
        auto validatorPtr = (validator);
        MockPersistentStore<std::string, BaseValue> persistentStore{"", validatorPtr};
        std::remove("pewpew.txt");
        PersistentStore<std::string, BaseValue> store2{"pewpew.txt", "", &Value::createValue};
        SessionAttributeManager attributeManager(persistentStore, store2, validatorPtr);


        ASSERT_TRUE(attributeManager.generateJSONObject()->size() == 0);

        attributeManager.addNRAttribute(Attribute<const char *>::createAttribute("NROnly",
                                                                                 [](const char *) { return true; },
                                                                                 "blah",
                                                                                 [](const char *) { return true; }));
        attributeManager.addSessionAttribute("blah", "blah");

        auto json = attributeManager.generateJSONObject();

        ASSERT_TRUE((*json)["NROnly"].as_string() == "blah");
        ASSERT_TRUE((*json)["blah"].as_string() == "blah");
    }

    TEST(SessionAttributes, testIncrementAttribute) {
        AttributeValidator validator = AttributeValidator(
                [](const char *name) { return strlen(name) < 10; },
                [](const char *value) { return strlen(value) < 10; },
                [](const char *) { return true; });
        auto validatorPtr = (validator);
        MockPersistentStore<std::string, BaseValue> persistentStore{"", validatorPtr};
        std::remove("pewpew.txt");
        PersistentStore<std::string, BaseValue> store2{"pewpew.txt", "", &Value::createValue};
        SessionAttributeManager attributeManager(persistentStore, store2, validatorPtr);

        ASSERT_TRUE(attributeManager.addSessionAttribute("test", 20.0f));
        ASSERT_TRUE(attributeManager.incrementAttribute("test", 5.0f));

        ASSERT_TRUE(attributeManager.incrementAttribute("blah", 10.0f));

        ASSERT_TRUE(attributeManager.addSessionAttribute("1", "2"));

        ASSERT_FALSE(attributeManager.incrementAttribute("1", 10.0f));

        ASSERT_TRUE(attributeManager.addSessionAttribute("crazydude", "Mr. T", true));
        auto json = attributeManager.generateJSONObject();

        ASSERT_TRUE((*json)["test"].as_float() == 25.0f);
        ASSERT_TRUE((*json)["blah"].as_float() == 10.0f);
        ASSERT_TRUE((*json)["crazydude"].as_string() == "Mr. T");
    }

    TEST_F(SessionAttributesTest, testThreading) {
        AttributeValidator validator([](const char *name) {
            return strlen(name) < 10;
        }, [](const char *value) {
            return strlen(value) < 10;
        },
        [](const char *) { return true;});
        auto validatorPtr = (validator);
        MockPersistentStore<std::string, BaseValue> persistentStore{"", validatorPtr};
        std::remove("pewpew.txt");
        PersistentStore<std::string, BaseValue> store2{"pewpew.txt", "", &Value::createValue};
        SessionAttributeManager attributeManager(persistentStore, store2, validatorPtr);
        attributeManager.addSessionAttribute("removeMe", "blah");

        std::thread th1{[&attributeManager]() {
            for (int i = 0; i < 10; i++) {
                attributeManager.addSessionAttribute("1", (double) i);
                std::this_thread::sleep_for(std::chrono::milliseconds(10));
            }
        }};

        std::thread th2{[&attributeManager]() {
            for (int i = 10; i < 20; i++) {
                attributeManager.addSessionAttribute("2", (double) i);
                std::this_thread::sleep_for(std::chrono::milliseconds(10));
            }
        }};

        std::thread th3{[&attributeManager]() {
            for (int i = 20; i < 30; i++) {
                attributeManager.addSessionAttribute("3", (double) i);
                std::this_thread::sleep_for(std::chrono::milliseconds(10));
            }
        }};

        std::thread th7{&SessionAttributeManager::removeSessionAttribute, &attributeManager, "removeMe"};

        std::thread th4{[&attributeManager]() {
            for (int i = 30; i < 40; i++) {
                attributeManager.addSessionAttribute("4", (double) i);
                std::this_thread::sleep_for(std::chrono::milliseconds(10));
            }
        }};

        std::thread th5{[&attributeManager]() {
            for (int i = 40; i < 50; i++) {
                attributeManager.addSessionAttribute("5", (double) i);
                std::this_thread::sleep_for(std::chrono::milliseconds(10));
            }
        }};

        std::thread th6{[&attributeManager]() {
            for (int i = 50; i < 60; i++)
                attributeManager.addSessionAttribute("6", (double) i);
        }};

        th1.join();
        th2.join();
        th3.join();
        th4.join();
        th5.join();
        th6.join();
        th7.join();

        auto json = attributeManager.generateJSONObject();
        ASSERT_TRUE((*json)["1"].as_float() == 9.0f);
        ASSERT_TRUE((*json)["2"].as_float() == 19.0f);
        ASSERT_TRUE((*json)["3"].as_float() == 29.0f);
        ASSERT_TRUE((*json)["4"].as_float() == 39.0f);
        ASSERT_TRUE((*json)["5"].as_float() == 49.0f);
        ASSERT_TRUE((*json)["6"].as_float() == 59.0f);
    };

    TEST_F(SessionAttributesTest, testAttributeValidation) {
        auto validatorPtr = validator;
        MockPersistentStore<std::string, BaseValue> persistentStore{"", validator};
        PersistentStore<std::string, BaseValue> store{storeName, "", &Value::createValue};
        SessionAttributeManager attributeManager(persistentStore, store, validatorPtr);

        ASSERT_FALSE(attributeManager.addSessionAttribute("123456789011",
                                                          "world"));        //fails attributeValidator for Name
        ASSERT_FALSE(attributeManager.addSessionAttribute("blah",
                                                          "123456789011"));         //fails attributeValidator for Value
        ASSERT_FALSE(attributeManager.addSessionAttribute("123456789011",
                                                          10.0f));          //fails attributeValidator for Value
        ASSERT_FALSE(attributeManager.addSessionAttribute("123456789011", 10.0f,
                                                          true));    //fails attributeValidator for Value
        ASSERT_FALSE(attributeManager.addSessionAttribute("123456789011", "world",
                                                          true));  //fails attributeValidator for Name
        ASSERT_FALSE(attributeManager.addSessionAttribute("blah", "123456789011",
                                                          true));   //fails attributeValidator for Value
    }
};
