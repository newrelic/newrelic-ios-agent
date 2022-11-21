project(Utilities)

include_directories(
    "include"
    ".")

add_library(Utilities
        src/Application.cxx
        src/ApplicationContext.cxx
        src/Number.cxx
        src/String.cxx
        src/BaseValue.cxx
        src/Boolean.cxx
        src/Value.cxx
        src/Util.cxx
        src/LibLogger.cxx
        src/DefaultLogger.cxx
        src/WorkQueue.cxx
        src/UUID.cxx)


target_link_libraries(Utilities)

set(UTILITIES_LIBS_DIR ${CMAKE_CURRENT_SOURCE_DIR} PARENT_SCOPE)
