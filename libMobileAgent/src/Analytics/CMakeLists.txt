project(Analytics)

include_directories(
        ${json_SOURCE_DIR}/..
        ${UTILITIES_LIBS_DIR}/include
        ${CONNECTIVITY_LIBS_DIR}/include
        "include/Events"
        "include/Stores"
        "include"
        "."
)



add_library(Analytics
        src/Events/BreadcrumbEvent.cxx
        src/Events/NetworkErrorEvent.cxx
        src/Events/RequestEvent.cxx
        src/Events/CustomMobileEvent.cxx
        src/Events/CustomEvent.cxx
        src/Events/NamedAnalyticEvent.cxx
        src/Events/InteractionAnalyticEvent.cxx
        src/Events/IntrinsicEvent.cxx
        src/Events/SessionAnalyticEvent.cxx
        src/NetworkRequestData.cxx
        src/NetworkResponseData.cxx
        src/SessionAttributeManager.cxx
        src/Attribute.cxx
        src/AttributeBase.cxx
        src/AttributeValidator.cxx
        src/EventManager.cxx
        src/Constants.cxx
        src/Events/AnalyticEvent.cxx
        src/AnalyticsController.cxx
        src/Events/MobileEvent.cxx
        src/Events/UserActionEvent.cxx
        src/EventDeserializer.cxx
        src/AttributeDeserializer.cxx
        src/Deserializer.cxx
        src/EventBufferConfig.cxx)


add_dependencies(Analytics
  Utilities json Connectivity)

target_link_libraries(Analytics Utilities json Connectivity)

set(ANALYTICS_LIBS_DIR ${CMAKE_CURRENT_SOURCE_DIR} PARENT_SCOPE)