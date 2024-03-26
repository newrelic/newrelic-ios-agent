//
//  NRMAUIViewDetails.h
//  Agent_iOS
//
//  Created by Steve Malsam on 2/26/24.
//  Copyright © 2024 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#import "NRMAViewDetailProtocol.h"

NS_ASSUME_NONNULL_BEGIN

@interface NRMAUIViewDetails : NSObject<NRMAViewDetailProtocol>

@property (nonatomic, assign) NSInteger viewId;
@property (nonatomic, assign) CGRect frame;
@property (nonatomic, strong) UIColor* backgroundColor;
@property (nonatomic, assign) BOOL isHidden;
@property (nonatomic, strong) NSString* viewName;

- (instancetype)initWithView:(UIView *)view;
- (NSDictionary *)jsonDescription;

@end

NS_ASSUME_NONNULL_END

