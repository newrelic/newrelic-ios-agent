//
//  Constants.h
//  Agent
//
//  Created by Mike Bruin on 8/9/23.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSString *const kNRMA_RA_eventType;
extern NSString *const kNRMA_RA_type;
extern NSString *const kNRMA_RA_timestamp;
extern NSString *const kNRMA_RA_category;
extern NSString *const kNRMA_RA_accountId;
extern NSString *const kNRMA_RA_appId;
extern NSString *const kNRMA_RA_appName;
extern NSString *const kNRMA_RA_uuid;
extern NSString *const kNRMA_RA_sessionDuration;
extern NSString *const kNRMA_RA_sessionElapsedTime;
extern NSString *const kNRMA_RA_payload;
extern NSString *const kNRMA_RA_InteractionDuration;
extern NSString *const kNRMA_RA_osName;
extern NSString *const kNRMA_RA_osVersion;
extern NSString *const kNRMA_RA_osMajorVersion;
extern NSString *const kNRMA_RA_deviceManufacturer;
extern NSString *const kNRMA_RA_deviceModel;
extern NSString *const kNRMA_RA_carrier;
extern NSString *const kNRMA_RA_newRelicVersion;
extern NSString *const kNRMA_RA_memUsageMb;
extern NSString *const kNRMA_RA_sessionId;
extern NSString *const kNRMA_RA_install;
extern NSString *const kNRMA_RA_upgradeFrom;
extern NSString *const kNRMA_RA_platform;
extern NSString *const kNRMA_RA_platformVersion;
extern NSString *const kNRMA_RA_lastInteraction;
extern NSString *const kNRMA_RA_appDataHeader;
extern NSString *const kNRMA_RA_responseBody;

extern NSString *const kNRMA_RET_mobile;
extern NSString *const kNRMA_RET_mobileSession;
extern NSString *const kNRMA_RET_mobileRequest;
extern NSString *const kNRMA_RET_mobileRequestError;
extern NSString *const kNRMA_RET_mobileCrash;
extern NSString *const kNRMA_RET_mobileBreadcrumb;
extern NSString *const kNRMA_RET_mobileUserAction;

extern NSString *const kNRMA_RA_methodExecuted;
extern NSString *const kNRMA_RA_targetObject;
extern NSString *const kNRMA_RA_label;
extern NSString *const kNRMA_RA_accessibility;
extern NSString *const kNRMA_RA_touchCoordinates;
extern NSString *const kNMRA_RA_actionType;
extern NSString *const kNRMA_RA_frame;
extern NSString *const kNRMA_RA_orientation;

extern NSString *const kNRMA_RP_newRelic;
extern NSString *const kNRMA_RP_nr;

extern NSString *const kNRMA_Attrib_guid;
extern NSString *const kNRMA_Attrib_traceId;
extern NSString *const kNRMA_Attrib_parentId;
extern NSString *const kNRMA_Attrib_userId;

extern NSString *const kNRMA_Attrib_connectionType;
extern NSString *const kNRMA_Attrib_requestUrl;
extern NSString *const kNRMA_Attrib_requestDomain;
extern NSString *const kNRMA_Attrib_requestPath;
extern NSString *const kNRMA_Attrib_requestMethod;
extern NSString *const kNRMA_Attrib_bytesReceived;
extern NSString *const kNRMA_Attrib_bytesSent;
extern NSString *const kNRMA_Attrib_responseTime;
extern NSString *const kNRMA_Attrib_statusCode;
extern NSString *const kNRMA_Attrib_networkErrorCode;
extern NSString *const kNRMA_Attrib_networkError;
extern NSString *const kNRMA_Attrib_errorType;
extern NSString *const kNRMA_Attrib_contentType;
extern NSString *const kNRMA_Attrib_dtGuid;
extern NSString *const kNRMA_Attrib_dtId;
extern NSString *const kNRMA_Attrib_dtTraceId;
extern NSString *const kNRMA_Attrib_name;

extern NSString *const kNRMA_Val_errorType_HTTP;
extern NSString *const kNRMA_Val_errorType_Network;

extern NSString *const kNRMA_Attrib_file;
extern NSString *const kNRMA_Attrib_file_private;


// Integer Analytics Constants
static int kNRMA_Attrib_Max_Name_Length = 256;
static int kNRMA_Attrib_Max_Value_Size_Bytes = 4096;
static int kNRMA_Attrib_Max_Number_Attributes = 128;
