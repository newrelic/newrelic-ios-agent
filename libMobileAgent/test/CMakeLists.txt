

add_executable(${PROJECT_TEST_NAME}
        ${PROJECT_SOURCE_DIR}/test/AnalyticsTest/AnalyticsEvent_test.cxx
        ${PROJECT_SOURCE_DIR}/test/AnalyticsTest/Attribute_test.cxx
        ${PROJECT_SOURCE_DIR}/test/AnalyticsTest/AnalyticController_test.cxx
        ${PROJECT_SOURCE_DIR}/test/AnalyticsTest/SessionController_test.cxx
        ${PROJECT_SOURCE_DIR}/test/AnalyticsTest/EventManager_test.cxx
        ${PROJECT_SOURCE_DIR}/test/AnalyticsTest/FileBackedStore_test.cxx
        ${PROJECT_SOURCE_DIR}/test/AnalyticsTest/PersistentStore_test.cxx
        ${PROJECT_SOURCE_DIR}/test/UtilitiesTest/Number_test.cxx
        ${PROJECT_SOURCE_DIR}/test/UtilitiesTest/Boolean_test.cxx
        ${PROJECT_SOURCE_DIR}/test/UtilitiesTest/String_test.cxx
        ${PROJECT_SOURCE_DIR}/test/UtilitiesTest/UUID_test.cxx
        ${PROJECT_SOURCE_DIR}/test/UtilitiesTest/Util_test.cxx
        ${PROJECT_SOURCE_DIR}/test/UtilitiesTest/WorkQueue_test.cxx
        ${PROJECT_SOURCE_DIR}/test/HexTests/HexPublisher_test.cxx
        ${PROJECT_SOURCE_DIR}/test/HexTests/HexReport_test.cxx
        ${PROJECT_SOURCE_DIR}/test/HexTests/LibraryController_test.cxx
        ${PROJECT_SOURCE_DIR}/test/HexTests/HexAudit_test.cxx
        ${PROJECT_SOURCE_DIR}/test/ConnectivityTest/Facade_test.cxx

        )
add_dependencies(${PROJECT_TEST_NAME} gmock gtest Utilities Analytics json Hex Connectivity)

target_link_libraries(${PROJECT_TEST_NAME} ${CMAKE_THREAD_LIBS_INIT} c++ pthread gmock gmock_main json gtest sqlite3 Utilities Analytics Hex Connectivity)
