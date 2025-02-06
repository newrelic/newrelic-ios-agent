//
//  NRMASessionReplay.h
//  Agent_iOS
//
//  Created by Steve Malsam on 2/26/24.
//  Copyright © 2024 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

void NRMAOverride__sendEvent(id self, SEL _cmd, UIEvent* event);

@interface NRMASessionReplayObjC : NSObject
- (void) NRMAOverride__interceptAndRecordTouches:(UIEvent *)event;
@end

NS_ASSUME_NONNULL_END
