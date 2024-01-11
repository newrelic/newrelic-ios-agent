//
//  Constants.m
//  Agent
//
//  Created by Mike Bruin on 8/9/23.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Constants.h"

NSString * const kNRMA_RA_eventType          = @"eventType";
NSString * const kNRMA_RA_type               = @"type";
NSString * const kNRMA_RA_timestamp          = @"timestamp";
NSString * const kNRMA_RA_category           = @"category";
NSString * const kNRMA_RA_accountId          = @"accountId";
NSString * const kNRMA_RA_appId              = @"appId";
NSString * const kNRMA_RA_appName            = @"appName";
NSString * const kNRMA_RA_uuid               = @"uuid";
NSString * const kNRMA_RA_sessionDuration    = @"sessionDuration";
NSString * const kNRMA_RA_sessionElapsedTime = @"timeSinceLoad";
NSString * const kNRMA_RA_payload            = @"payload";
NSString * const kNRMA_RA_InteractionDuration = @"interactionDuration";
NSString * const kNRMA_RA_osName             = @"osName";
NSString * const kNRMA_RA_osVersion          = @"osVersion";
NSString * const kNRMA_RA_osMajorVersion     = @"osMajorVersion";
NSString * const kNRMA_RA_deviceManufacturer = @"deviceManufacturer";
NSString * const kNRMA_RA_deviceModel        = @"deviceModel";
NSString * const kNRMA_RA_carrier            = @"carrier";
NSString * const kNRMA_RA_newRelicVersion    = @"newRelicVersion";
NSString * const kNRMA_RA_memUsageMb         = @"memUsageMb";
NSString * const kNRMA_RA_sessionId          = @"sessionId";
NSString * const kNRMA_RA_install            = @"install";
NSString * const kNRMA_RA_upgradeFrom        = @"upgradeFrom";
NSString * const kNRMA_RA_platform           = @"platform";
NSString * const kNRMA_RA_platformVersion    = @"platformVersion";
NSString * const kNRMA_RA_lastInteraction    = @"lastInteraction";
NSString * const kNRMA_RA_appDataHeader      = @"nr.X-NewRelic-App-Data";
NSString * const kNRMA_RA_responseBody       = @"nr.responseBody";

//reserved mobile eventTypes
NSString * const kNRMA_RET_mobile               = @"Mobile";
NSString * const kNRMA_RET_mobileSession        = @"MobileSession";
NSString * const kNRMA_RET_mobileRequest        = @"MobileRequest";
NSString * const kNRMA_RET_mobileRequestError   = @"MobileRequestError";
NSString * const kNRMA_RET_mobileCrash          = @"MobileCrash";
NSString * const kNRMA_RET_mobileBreadcrumb     = @"MobileBreadcrumb";
NSString * const kNRMA_RET_mobileUserAction     = @"MobileUserAction";

//gesture attributes (not reserved)
NSString * const kNRMA_RA_methodExecuted     = @"methodExecuted";
NSString * const kNRMA_RA_targetObject       = @"targetObject";
NSString * const kNRMA_RA_label              = @"label";
NSString * const kNRMA_RA_accessibility      = @"accessibility";
NSString * const kNRMA_RA_touchCoordinates   = @"touchCoordinates";
NSString * const kNMRA_RA_actionType         = @"actionType";
NSString * const kNRMA_RA_frame              = @"controlRect";
NSString * const kNRMA_RA_orientation        = @"orientation";
//reserved prefix
NSString * const kNRMA_RP_newRelic           = @"newRelic";
NSString * const kNRMA_RP_nr                 = @"nr.";

//Intrinsic Event Attributes (not reserved)
NSString * const kNRMA_Attrib_guid           = @"guid";
NSString * const kNRMA_Attrib_traceId        = @"traceId";
NSString * const kNRMA_Attrib_parentId       = @"nr.parentId";
NSString * const kNRMA_Attrib_userId         = @"userId";

//Request Event Attributes (not reserved)
NSString * const kNRMA_Attrib_connectionType    = @"connectionType";
NSString * const kNRMA_Attrib_requestUrl        = @"requestUrl";
NSString * const kNRMA_Attrib_requestDomain     = @"requestDomain";
NSString * const kNRMA_Attrib_requestPath       = @"requestPath";
NSString * const kNRMA_Attrib_requestMethod     = @"requestMethod";
NSString * const kNRMA_Attrib_bytesReceived     = @"bytesReceived";
NSString * const kNRMA_Attrib_bytesSent         = @"bytesSent";
NSString * const kNRMA_Attrib_responseTime      = @"responseTime";
NSString * const kNRMA_Attrib_statusCode        = @"statusCode";
NSString * const kNRMA_Attrib_networkErrorCode  = @"networkErrorCode";
NSString * const kNRMA_Attrib_networkError      = @"networkError";
NSString * const kNRMA_Attrib_errorType         = @"errorType";
NSString * const kNRMA_Attrib_contentType       = @"contentType";
NSString * const kNRMA_Attrib_dtGuid            = @"guid";
NSString * const kNRMA_Attrib_dtId              = @"id";
NSString * const kNRMA_Attrib_dtTraceId         = @"trace.id";
NSString * const kNRMA_Attrib_name              = @"name";
NSString * const kNRMA_Attrib_offline           = @"offline";

NSString * const kNRMA_Val_errorType_HTTP       = @"HTTPError";
NSString * const kNRMA_Val_errorType_Network    = @"NetworkFailure";


NSString * const kNRMA_Attrib_file       = @"attributes.txt";
NSString * const kNRMA_Attrib_file_private    = @"privateAttributes.txt";

NSString * const kNRMA_Offline_folder          = @"offlineStorage";
