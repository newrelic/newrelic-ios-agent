#include <Analytics/Attribute.hpp>
#include <Analytics/Events/CustomMobileEvent.hpp>
#include <gmock/gmock.h>
using ::testing::Eq;
using ::testing::Test;

namespace NewRelic {

    TEST(AnalyticsEvent, testCreateAttributes) {
        auto p1 = Attribute<const char *>::createAttribute("blah",
                                                           [](const char*){ return true;},
                                                           "100",
                                                           [](const char*){return true;});
        ASSERT_TRUE(p1 != nullptr);
        ASSERT_EQ(p1->getName(), "blah");
        auto val = p1->getValue();
        ASSERT_TRUE(*val == *Value::createValue("100"));
        ASSERT_FALSE(*val == *Value::createValue(100));

        p1 = Attribute<int>::createAttribute("blah",
                                              [](const char*){ return true;},
                                              100,
                                              [](int){return true;});
        ASSERT_TRUE(p1 != nullptr);
        val = p1->getValue();
        ASSERT_TRUE(*val == *Value::createValue(100));
        ASSERT_FALSE(*val == *Value::createValue("100"));

        auto p2 = Attribute<int>::createAttribute("blah",
                                             [](const char*){ return true;},
                                             100,
                                             [](int){return true;});

        ASSERT_EQ(*p1, *p2);

    }

    TEST(AnalyticsEvent,testAttributeSerializationWithEscapeCharacters) {
        auto p1 = Attribute<const char *>::createAttribute("blah\t\r\b\a\v\f\n",
                                                           [](const char*){ return true;},
                                                           "100\t\r\b\a\v\f\n",
                                                           [](const char*){return true;});

        ASSERT_TRUE(std::dynamic_pointer_cast<String>(p1->getValue())->getValue().compare("100\\t\\r\\b\\a\\v\\f\\n") == 0);
        ASSERT_TRUE(p1->getName().compare("blah\\t\\r\\b\\a\\v\\f\\n") == 0);
    }
}
