cmake_minimum_required(VERSION 2.8)

project(json)

if(NOT CMAKE_BUILD_TYPE)
	set(
		CMAKE_BUILD_TYPE Release
		CACHE STRING
		"Choose the type of build, options are: None Debug Release RelWithDebInfo MinSizeRel Coverage."
		FORCE
	)
endif()

set(CMAKE_CXX_FLAGS "-O3")

include(CheckCXXCompilerFlag)
CHECK_CXX_COMPILER_FLAG("-std=c++14" COMPILER_SUPPORTS_CXX14)
CHECK_CXX_COMPILER_FLAG("-std=c++11" COMPILER_SUPPORTS_CXX11)
CHECK_CXX_COMPILER_FLAG("-std=c++0x" COMPILER_SUPPORTS_CXX0X)
if(COMPILER_SUPPORTS_CXX14)
	set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -std=c++14")
elseif(COMPILER_SUPPORTS_CXX11)
  set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -std=c++11")
elseif(COMPILER_SUPPORTS_CXX0X)
  set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -std=c++0x")
else()
        message(STATUS "The compiler ${CMAKE_CXX_COMPILER} has no C++11 support. Please use a different C++ compiler.")
endif()

string(TOLOWER ${CMAKE_BUILD_TYPE} BUILD_TYPE_LOWER)
if(BUILD_TYPE_LOWER STREQUAL "coverage")
	# workaround necessary because CHECK_CXX_COMPILER_FLAG not only compiles, but also links,
	# but while linking, it does not specify the flag, which in this case must also be present
	# in the linker invocation. Without setting the flag here manually, the macro would fail
	# while linking.
	set(CMAKE_CXX_FLAGS_COVERAGE "${CMAKE_CXX_FLAGS_COVERAGE} -coverage")
	CHECK_CXX_COMPILER_FLAG("" COMPILER_SUPPORTS_COVERAGE)
	if(NOT COMPILER_SUPPORTS_COVERAGE)
		message(FATAL_ERROR "Your compiler does not support compiling for code coverage")
	endif()
endif()

include_directories(
  ${UTILITIES_LIBS_DIR}/include
)

if (BUILD_JSON)
	# On macOS, search Homebrew for keg-only versions of Bison and Flex. Xcode does
	# not provide new enough versions for us to use.
	if (CMAKE_HOST_SYSTEM_NAME MATCHES "Darwin")
		execute_process(
			COMMAND brew --prefix bison
			RESULT_VARIABLE BREW_BISON
			OUTPUT_VARIABLE BREW_BISON_PREFIX
			OUTPUT_STRIP_TRAILING_WHITESPACE
		)
		message(STATUS "brew --prefix bison result was ${BREW_BISON}")
		if (BREW_BISON EQUAL 0 AND EXISTS "${BREW_BISON_PREFIX}")
			message(STATUS "Found Bison keg installed by Homebrew at ${BREW_BISON_PREFIX}")
			set(BISON_EXECUTABLE "${BREW_BISON_PREFIX}/bin/bison")
		else()
			message(STATUS "Didn't Change BISON executable.")
		endif()

		execute_process(
			COMMAND brew --prefix flex
			RESULT_VARIABLE BREW_FLEX
			OUTPUT_VARIABLE BREW_FLEX_PREFIX
			OUTPUT_STRIP_TRAILING_WHITESPACE
		)
		if (BREW_FLEX EQUAL 0 AND EXISTS "${BREW_FLEX_PREFIX}")
			message(STATUS "Found Flex keg installed by Homebrew at ${BREW_FLEX_PREFIX}")
			set(FLEX_EXECUTABLE "${BREW_FLEX_PREFIX}/bin/flex")
		endif()
	endif()
find_package(BISON 3.0.4 REQUIRED)
set(BISON_OUTPUT ${json_BINARY_DIR}/json.tab.cc)
set(BISON_DEFINES ${json_BINARY_DIR}/json.tab.hh)
include_directories(${json_SOURCE_DIR} ${json_BINARY_DIR})
MESSAGE(WARNING "flex output: ${json_SOURCE_DIR} ${json_BINARY_DIR}")

if(BISON_FOUND)
	add_custom_command(
		OUTPUT ${BISON_OUTPUT}
		COMMAND ${BISON_EXECUTABLE}
			--defines=${BISON_DEFINES}
			--output=${BISON_OUTPUT}
			${json_SOURCE_DIR}/json.y
		DEPENDS ${json_SOURCE_DIR}/json.y
		COMMENT "Generating json.tab.hh, json.tab.cc (parser)"
	)
endif(BISON_FOUND)

find_package(FLEX 2.6 REQUIRED)
set(FLEX_OUTPUT ${json_BINARY_DIR}/lex.yy.cc)
if(FLEX_FOUND)
	add_custom_command(
		OUTPUT ${FLEX_OUTPUT}
		COMMAND ${FLEX_EXECUTABLE}
			--outfile=${FLEX_OUTPUT}
			${json_SOURCE_DIR}/json.l
		DEPENDS ${json_SOURCE_DIR}/json.l
		COMMENT "Generating lex.yy.cc (lexer)"
	)
#set_source_files_properties(${FLEX_OUTPUT} PROPERTIES COMPILE_FLAGS )
endif(FLEX_FOUND)
endif(BUILD_JSON)
add_library(json json_st.cc IJsonable.hpp ${BISON_OUTPUT} ${FLEX_OUTPUT})
add_dependencies(json Utilities)
target_link_libraries(json Utilities)
#add_executable(test test.cc)
#target_link_libraries(test json)
#
#
#option(WITH_UNIT_TESTS "build unit tests, requires cppunit framework")
#
#if (WITH_UNIT_TESTS)
#	message(STATUS "Building with unit tests")
#	enable_testing()
#	add_test(json ut/ut.json)
#	include(CTest)
#	add_subdirectory(ut)
#endif(WITH_UNIT_TESTS)

# add a target to generate API documentation with Doxygen
#find_package(Doxygen)
#if(DOXYGEN_FOUND)
#	if(DOT)
#		set(HAVE_DOT YES)
#	else(DOT)
#		set(HAVE_DOT NO)
#	endif(DOT)
#	configure_file(
#		${json_SOURCE_DIR}/Doxyfile.in ${json_BINARY_DIR}/Doxyfile
#		@ONLY}
#	)
#	add_custom_target(
#		doc ALL
#		${DOXYGEN_EXECUTABLE} ${json_BINARY_DIR}/Doxyfile
#		WORKING_DIRECTORY ${json_BINARY_DIR}
#		COMMENT "Generating API documentation with Doxygen" VERBATIM
#	)
#endif(DOXYGEN_FOUND)
