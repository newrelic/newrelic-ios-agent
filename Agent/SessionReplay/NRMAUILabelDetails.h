//
//  NRMAUILabelDetails.h
//  Agent_iOS
//
//  Created by Steve Malsam on 2/29/24.
//  Copyright © 2024 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#import "NRMAViewDetailProtocol.h"

NS_ASSUME_NONNULL_BEGIN

@interface NRMAUILabelDetails : NSObject<NRMAViewDetailProtocol>

@property (nonatomic, assign) NSInteger viewId;
@property (nonatomic, assign) CGRect frame;
@property (nonatomic, strong) UIColor* backgroundColor;
@property (nonatomic, assign) BOOL isHidden;
@property (nonatomic, strong) NSString* viewName;
@property (nonatomic, strong) NSString* labelText;
@property (nonatomic, assign) CGFloat fontSize;
@property (nonatomic, strong) NSString* fontName;
@property (nonatomic, strong) NSString* fontFamily; 
@property (nonatomic, strong) UIColor* textColor;

- (instancetype)initWithView:(UIView *)view;
- (NSDictionary *)jsonDescription;


@end

NS_ASSUME_NONNULL_END
