#include <iostream>
#include <gmock/gmock.h>
using ::testing::Eq;

#include <Utilities/Value.hpp>


namespace NewRelic {
    TEST(String, serialize) {
        auto str = Value::createValue("blah");
        std::stringstream stream;
        stream << (*str);

        auto str2 = Value::createValue(stream);

        EXPECT_TRUE((*str) == *str2);
    }

    TEST(String, serializeWithSpaces) {
        auto str = Value::createValue("blah blah blah");
        std::stringstream stream;

        stream << (*str);

        auto str2 = Value::createValue(stream);

        EXPECT_TRUE((*str)== (*str2));
    }

    TEST(String, serializeWithTabs) {
        auto str = Value::createValue("blah blah\\tblah");
        auto str_expect = Value::createValue("blah blah\\tblah");
        std::stringstream stream;

        stream << (*str);

        auto str2 = Value::createValue(stream);

        EXPECT_TRUE((*str_expect) == (*str2));
    }

    TEST(String, serializeWithEscapeCharacters) {
        auto strUnescaped = Value::createValue("blah\rblah\ablah\nblah\fblah\b");
        auto strExpected= Value::createValue("blah\\rblah\\ablah\\nblah\\fblah\\b");

        std::stringstream stream;
        stream << (*strUnescaped);

        auto strEscaped = Value::createValue(stream);
        EXPECT_TRUE((*strExpected) == (*strEscaped));
    }

}
