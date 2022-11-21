project(Connectivity)

include_directories(
        "include"
        ${UTILITIES_LIBS_DIR}/include
        ${json_SOURCE_DIR}/..
        ".")

add_library(Connectivity
        src/Facade.cxx
        src/Payload.cxx
        src/GuidGenerator.cxx
        src/PayloadType.cxx)

add_dependencies(Connectivity
        json
        Utilities)

target_link_libraries(Connectivity json Utilities)

set(CONNECTIVITY_LIBS_DIR ${CMAKE_CURRENT_SOURCE_DIR} PARENT_SCOPE)