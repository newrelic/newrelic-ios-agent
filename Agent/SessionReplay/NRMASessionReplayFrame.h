//
//  NRMASessionReplayFrame.h
//  Agent_iOS
//
//  Created by Steve Malsam on 9/20/24.
//  Copyright © 2024 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NRMASessionReplayFrame : NSObject

-(void)addStyleNodes:(NSString *)styleNodes;
-(void)addBodyNodes:(NSDictionary *)bodyNodes;
-(NSDictionary *)getFrame;

@end

NS_ASSUME_NONNULL_END
