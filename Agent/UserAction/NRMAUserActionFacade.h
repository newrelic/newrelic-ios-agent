//
//  NRMAUserActionFacade.h
//  NewRelicAgent
//  Copyright © 2023 New Relic. All rights reserved.
//

#import "NRMAUserAction.h"
#import "NRMAAnalytics.h"

@interface NRMAUserActionFacade : NSObject

-(instancetype) initWithAnalyticsController:(NRMAAnalytics*)analytics;
-(void)recordUserAction:(NRMAUserAction*)userAction;

@end

