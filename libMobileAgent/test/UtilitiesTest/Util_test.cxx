//
// Created by Bryce Buchanan on 8/10/15.
//

#include <iostream>
#include <gmock/gmock.h>
#include <Utilities/Util.hpp>
#include <Hex/report/exception/Frame.hpp>

using ::testing::Eq;
using  NewRelic::Hex::Report::Frame;

namespace NewRelic {
    TEST(Util,escapingWhitespaceTest) {
        std::string testString = std::string("\n\rhello\tworld\v\fblah blah blah\t\n\r\v\f");
        std::string str = Util::Strings::escapeCharacterLiterals("\t\t\t");
        ASSERT_TRUE(str.compare("\\t\\t\\t") == 0);
        ASSERT_TRUE(Util::Strings::escapeCharacterLiterals(testString).compare("\\n\\rhello\\tworld\\v\\fblah blah blah\\t\\n\\r\\v\\f")==0);

    }

    TEST(Util, frameStringToAddress) {
        ASSERT_EQ(0xdeadbeef, Frame::frameStringToAddress((const char *) "0 lol     0xdeadbeef   other stuff\""));
        ASSERT_EQ(0xcafebabe, Frame::frameStringToAddress((const char *) "1    blahblah      0xcafebabe"));
        ASSERT_EQ(0, Frame::frameStringToAddress((const char *) "1    bad bad"));
        ASSERT_EQ(0, Frame::frameStringToAddress(NULL));
        ASSERT_EQ(0, Frame::frameStringToAddress((const char *) "   "));

    }
}
