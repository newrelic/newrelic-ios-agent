//
// Created by Jared Stanbrough on 6/26/17.
//
#include <gmock/gmock.h>
#include <Hex/LibraryController.hpp>

using ::testing::_;
using ::testing::Test;

using NewRelic::LibraryController;

namespace NewRelic {
    class LibraryControllerTest : public ::testing::Test {

    };

    TEST(LibraryController, testDyldHandler) {
        LibraryController& controller = LibraryController::getInstance();

        ASSERT_TRUE(controller.num_images() > 2);

        ASSERT_NO_THROW(controller.getAppImage());

        for (auto& library : controller.libraries()) {
            ASSERT_TRUE(library.getSize() > 0);
            ASSERT_TRUE(library.uuidLow() != 0);
            ASSERT_TRUE(library.uuidHigh() != 0);
            ASSERT_TRUE(library.getName().size() > 0);
        }
    }
}
