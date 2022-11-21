    cmake_minimum_required(VERSION 2.8.12.2)

    INCLUDE(CPack)

    IF (DEFINED BUILD_TYPE)
      MESSAGE(WARNING "building for ${BUILD_TYPE}")
    ELSE ()
      set(BUILD_TYPE Debug)
      MESSAGE(WARNING "BUILD_TYPE not set. building for ${BUILD_TYPE}")
    ENDIF ()

    IF (DEFINED PLATFORM)
      MESSAGE(WARNING "building for ${PLATFORM}")
    ELSE ()
      set(PLATFORM iphoneos)
      MESSAGE(WARNING "PLATFORM not set. building for ${PLATFORM}")
    ENDIF ()




    set(CMAKE_CXX_STANDARD 14)

    IF ("${BUILD_TYPE}" STREQUAL Debug OR "${BUILD_TYPE}" STREQUAL Test)

      SET(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} ${GCC_COVERAGE_LINK_FLAGS}")

        add_definitions("-Wall \
                      -std=c++14 \
              -Wfatal-errors \
              -Wnewline-eof \
              -stdlib=libc++ \
              -DLLVM_ENABLE_PIC=False \
              -Wunused-function \
              -Wunused-label \
              -Wunused-value \
              -Wunused-variable \
              ${GCC_COVERAGE_COMPILE_FLAGS} \
              -g \
              -O0 \
              -c \
              -fno-inline \
              -D_GLIBCXX_DEBUG \
              -fvisibility-inlines-hidden \
              -fvisibility=hidden \
              -x c++"
      )
    ELSE ()
        add_definitions("-stdlib=libc++ \
              -std=c++14 \
              -DLLVM_ENABLE_PIC=False \
              -fembed-bitcode \
              -c \
              -Oz \
              -fvisibility-inlines-hidden \
              -fvisibility=hidden \
               -frtti \
              -x c++"
      )
      MESSAGE(WARNING "CMAKE_CXX_FLAGS ${CMAKE_CXX_FLAGS}")
    ENDIF ()
    set(CMAKE_XCODE_ATTRIBUTE_ONLY_ACTIVE_ARCH YES)
    MESSAGE(WARNING "CMAKE_CXX_FLAGS : ${CMAKE_CXX_FLAGS}")

    SET(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -arch ${ARCH_TYPE}")
    SET(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -arch ${ARCH_TYPE}")

	IF ("${PLATFORM}" STREQUAL macosx)
	        set(CMAKE_OSX_DEPLOYMENT_TARGET 11.0)
		IF ( "${ARCH_TYPE}" STREQUAL x86_64 )
			set(CMAKE_SYSTEM_NAME "Darwin")
            add_definitions(-arch x86_64 -target x86_64-apple-ios13.1-macabi)
            set(CMAKE_OSX_ARCHITECTURES x86_64)
		ENDIF ()
	ENDIF ()

	IF ("${PLATFORM}" STREQUAL macosx)
	        set(CMAKE_OSX_DEPLOYMENT_TARGET 11.0)
 		IF ( "${ARCH_TYPE}" STREQUAL arm64 )
			set(CMAKE_SYSTEM_NAME "Darwin")
            add_definitions(-arch arm64 -target arm64-apple-ios13.1-macabi)
            set(CMAKE_OSX_ARCHITECTURES arm64)
		ENDIF ()
	ENDIF ()

    IF ("${PLATFORM}" STREQUAL appletvos)
        set(CMAKE_OSX_DEPLOYMENT_TARGET 9.0)
      IF ("${ARCH_TYPE}" STREQUAL arm64)
          set(CMAKE_OSX_ARCHITECTURES arm64)
          set(CMAKE_OSX_SYSROOT "appletvos" CACHE INTERNAL "")
          add_definitions(-arch arm64 -target arm64-apple-tvos9.0)
      ENDIF ()
    ENDIF ()

    IF ("${PLATFORM}" STREQUAL appletvsimulator)
        set(CMAKE_OSX_DEPLOYMENT_TARGET 9.0)
        IF ("${ARCH_TYPE}" STREQUAL x86_64)
            set(CMAKE_OSX_ARCHITECTURES x86_64)
            set(CMAKE_OSX_SYSROOT "appletvsimulator" CACHE INTERNAL "")
            add_definitions(-arch x86_64 -target x86_64-apple-tvos9.0-simulator)
      ENDIF ()
        IF ("${ARCH_TYPE}" STREQUAL arm64)
            set(CMAKE_OSX_ARCHITECTURES arm64)
            set(CMAKE_OSX_SYSROOT "appletvsimulator" CACHE INTERNAL "")
            add_definitions(-arch arm64 -target arm64-apple-tvos9.0-simulator)
      ENDIF ()
    ENDIF ()


    IF ("${PLATFORM}" STREQUAL iphonesimulator)
        set(CMAKE_OSX_DEPLOYMENT_TARGET 8.0)
        IF ("${ARCH_TYPE}" STREQUAL x86_64)
            set(CMAKE_OSX_SYSROOT "iphonesimulator" CACHE INTERNAL "")
            set(CMAKE_OSX_ARCHITECTURES x86_64)
            add_definitions(-arch x86_64  -target x86_64-apple-ios8.0-simulator)
      ENDIF ()
      IF ("${ARCH_TYPE}" STREQUAL i386)
          set(CMAKE_OSX_SYSROOT "iphonesimulator" CACHE INTERNAL "")
          set(CMAKE_OSX_ARCHITECTURES i386)
          add_definitions(-arch i386  -target i386-apple-ios8.0-simulator)
      ENDIF ()
        IF ("${ARCH_TYPE}" STREQUAL arm64)
            set(CMAKE_OSX_SYSROOT "iphonesimulator" CACHE INTERNAL "")
            set(CMAKE_OSX_ARCHITECTURES arm64)
            add_definitions(-arch arm64  -target arm64-apple-ios8.0-simulator)
      ENDIF ()
    ENDIF ()

    IF ("${PLATFORM}" STREQUAL iphoneos)
        set(CMAKE_OSX_DEPLOYMENT_TARGET 8.0)

      IF ("${ARCH_TYPE}" STREQUAL arm64)
            set(CMAKE_OSX_SYSROOT "iphoneos" CACHE INTERNAL "")
            set(CMAKE_OSX_ARCHITECTURES arm64)
            add_definitions(-arch arm64 -target arm64-apple-ios8.0)
      ENDIF ()

      IF ("${ARCH_TYPE}" STREQUAL arm64e)
          set(CMAKE_OSX_SYSROOT "iphoneos" CACHE INTERNAL "")
          set(CMAKE_OSX_ARCHITECTURES arm64e)
          add_definitions(
                  -arch arm64e  -target arm64e-apple-ios8.0
          )
      ENDIF ()

      IF ("${ARCH_TYPE}" STREQUAL armv7)
          set(CMAKE_OSX_SYSROOT "iphoneos" CACHE INTERNAL "")
          set(CMAKE_OSX_ARCHITECTURES armv7)
          add_definitions(-arch armv7 -target armv7-apple-ios8.0)
      ENDIF ()

      IF ("${ARCH_TYPE}" STREQUAL armv7s)
          set(CMAKE_OSX_SYSROOT "iphoneos" CACHE INTERNAL "")
          set(CMAKE_OSX_ARCHITECTURES armv7s)
          add_definitions(-arch armv7s -target armv7s-apple-ios8.0)
      ENDIF ()
    ENDIF ()

    set(PROJECT_NAME_STR libMobileAgent)
    project(${PROJECT_NAME_STR} CXX C)
    find_package(threads REQUIRED)
    set(OUTPUT_DIR ${CMAKE_BINARY_DIR}/out)
    set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${OUTPUT_DIR})

    set(EXT_PROJECTS_DIR ${PROJECT_SOURCE_DIR}/ext)
    set(EXECUTABLE_OUTPUT_PATH ${PROJECT_SOURCE_DIR}/build)


    set(GMOCK $ENV{GMOCK_DIR})
    MESSAGE(WARNING "Using gmock dir ${GMOCK}")
    add_subdirectory(src/Utilities)

    IF ("${ENVIRONMENT}" STREQUAL CLION)
      MESSAGE(WARNING "ENVIRONMENT IS CLION")
      add_subdirectory(${EXT_PROJECTS_DIR}/JSON)
    ELSE ()
      MESSAGE(WARNING "ENVIRONMENT IS NOT CLION")
      add_subdirectory(${EXT_PROJECTS_DIR}/JSON ${EXT_PROJECTS_DIR}/JSON)
    ENDIF ()


    add_subdirectory(src/Connectivity)
    add_subdirectory(src/Analytics)
    add_subdirectory(src/Hex)

    include_directories(
            ${EXT_PROJECTS_DIR}/JSON
            ${EXT_PROJECTS_DIR}/flatbuffers/include
            src/Utilities/include
            src/Connectivity/include
            src/Analytics/include
            src/Hex/include)

#    set_target_properties(${PROJECT_NAME_STR} PROPERTIES
#            XCODE_ATTRIBUTE_ONLY_ACTIVE_ARCH "YES"
#            CMAKE_XCODE_ATTRIBUTE_CLANG_CXX_LANGUAGE_STANDARD "c++11")
    #-----------
    #- Test
    #-----------

    set(PROJECT_TEST_NAME ${PROJECT_NAME_STR}Test)

    if ("${BUILD_TYPE}" STREQUAL Test)
      add_subdirectory(${GMOCK} ${CMAKE_BINARY_DIR}/gmock)

      include_directories(
              ${GMOCK}/include
              ${EXT_PROJECTS_DIR}
              ${GMOCK}/gtest/include
              src/Utilities/include
              src/Connectivity/include
              src/Analytics/include
              src/Hex/include)

      enable_testing()

      add_definitions(
              -Wall
              -Wfatal-errors
              -Wnewline-eof
              -stdlib=libc++
              -DLLVM_ENABLE_PIC=False
              -Wunused-function
              -Wunused-label
              -Wunused-value
              -Wunused-variable
              ${GCC_COVERAGE_COMPILE_FLAGS}
              -g
              -O0
              -c
              -fno-inline
              -D_GLIBCXX_DEBUG
      )

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
              ${PROJECT_SOURCE_DIR}/test/UtilitiesTest/Application_test.cxx
              ${PROJECT_SOURCE_DIR}/test/HexTests/HexPublisher_test.cxx
              ${PROJECT_SOURCE_DIR}/test/HexTests/HexReport_test.cxx
              ${PROJECT_SOURCE_DIR}/test/HexTests/LibraryController_test.cxx
              ${PROJECT_SOURCE_DIR}/test/HexTests/HexAudit_test.cxx
              ${PROJECT_SOURCE_DIR}/test/HexTests/HexStore_test.cxx
              ${PROJECT_SOURCE_DIR}/test/HexTests/HexPersistenceManager_test.cxx
              ${PROJECT_SOURCE_DIR}/test/ConnectivityTest/Facade_test.cxx
              )

      add_dependencies(${PROJECT_TEST_NAME} gmock gtest Utilities Connectivity Analytics json Hex)

      target_link_libraries(${PROJECT_TEST_NAME} ${CMAKE_THREAD_LIBS_INIT} c++ pthread gmock gmock_main json gtest sqlite3 Utilities Connectivity Analytics Hex)
      add_test(test1 ${PROJECT_TEST_NAME})

    endif ()
