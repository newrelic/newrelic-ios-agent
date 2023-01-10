//  Copyright © 2023 New Relic. All rights reserved.

//reserved attributes
#include "Analytics/Constants.hpp"
const char* __kNRMA_RA_eventType          = "eventType";
const char* __kNRMA_RA_type               = "type";
const char* __kNRMA_RA_timestamp          = "timestamp";
const char* __kNRMA_RA_category           = "category";
const char* __kNRMA_RA_accountId          = "accountId";
const char* __kNRMA_RA_appId              = "appId";
const char* __kNRMA_RA_appName            = "appName";
const char* __kNRMA_RA_uuid               = "uuid";
const char* __kNRMA_RA_sessionDuration    = "sessionDuration";
const char* __kNRMA_RA_osName             = "osName";
const char* __kNRMA_RA_osVersion          = "osVersion";
const char* __kNRMA_RA_osMajorVersion     = "osMajorVersion";
const char* __kNRMA_RA_deviceManufacturer = "deviceManufacturer";
const char* __kNRMA_RA_deviceModel        = "deviceModel";
const char* __kNRMA_RA_carrier            = "carrier";
const char* __kNRMA_RA_newRelicVersion    = "newRelicVersion";
const char* __kNRMA_RA_memUsageMb         = "memUsageMb";
const char* __kNRMA_RA_sessionId          = "sessionId";
const char* __kNRMA_RA_install            = "install";
const char* __kNRMA_RA_upgradeFrom        = "upgradeFrom";
const char* __kNRMA_RA_platform           = "platform";
const char* __kNRMA_RA_platformVersion    = "platformVersion";
const char* __kNRMA_RA_lastInteraction    = "lastInteraction";
const char* __kNRMA_RA_appDataHeader      = "nr.X-NewRelic-App-Data";
const char* __kNRMA_RA_responseBody       = "nr.responseBody";

//reserved mobile eventTypes
const char* __kNRMA_RET_mobile               = "Mobile";
const char* __kNRMA_RET_mobileSession        = "MobileSession";
const char* __kNRMA_RET_mobileRequest        = "MobileRequest";
const char* __kNRMA_RET_mobileRequestError   = "MobileRequestError";
const char* __kNRMA_RET_mobileCrash          = "MobileCrash";
const char* __kNRMA_RET_mobileBreadcrumb     = "MobileBreadcrumb";
const char* __kNRMA_RET_mobileUserAction     = "MobileUserAction";

//gesture attributes (not reserved)
const char* __kNRMA_RA_methodExecuted     = "methodExecuted";
const char* __kNRMA_RA_targetObject       = "targetObject";
const char* __kNRMA_RA_label              = "label";
const char* __kNRMA_RA_accessibility      = "accessibility";
const char* __kNRMA_RA_touchCoordinates   = "touchCoordinates";
const char* __kNMRA_RA_actionType         = "actionType";
const char* __kNRMA_RA_frame              = "controlRect";
const char* __kNRMA_RA_orientation        = "orientation";
//reserved prefix
const char* __kNRMA_RP_newRelic           = "newRelic";
const char* __kNRMA_RP_nr                 = "nr.";

//Intrinsic Event Attributes (not reserved)
const char*  __kNRMA_Attrib_guid                      = "guid";
const char*  __kNRMA_Attrib_traceId                   = "traceId";
const char*  __kNRMA_Attrib_parentId                  = "nr.parentId";

//Request Event Attributes (not reserved)
const char* __kNRMA_Attrib_connectionType    = "connectionType";
const char* __kNRMA_Attrib_requestUrl        = "requestUrl";
const char* __kNRMA_Attrib_requestDomain     = "requestDomain";
const char* __kNRMA_Attrib_requestPath       = "requestPath";
const char* __kNRMA_Attrib_requestMethod     = "requestMethod";
const char* __kNRMA_Attrib_bytesReceived     = "bytesReceived";
const char* __kNRMA_Attrib_bytesSent         = "bytesSent";
const char* __kNRMA_Attrib_responseTime      = "responseTime";
const char* __kNRMA_Attrib_statusCode        = "statusCode";
const char* __kNRMA_Attrib_networkErrorCode  = "networkErrorCode";
const char* __kNRMA_Attrib_networkError      = "networkError";
const char* __kNRMA_Attrib_errorType         = "errorType";
const char* __kNRMA_Attrib_contentType       = "contentType";
const char* __kNRMA_Attrib_dtGuid            = "guid";
const char* __kNRMA_Attrib_dtId              = "id";
const char* __kNRMA_Attrib_dtTraceId         = "trace.id";

const char* __kNRMA_Val_errorType_HTTP       = "HTTPError";
const char* __kNRMA_Val_errorType_Network    = "NetworkFailure";







