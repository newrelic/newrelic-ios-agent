//
//  NRMAUIViewDetails.h
//  Agent_iOS
//
//  Created by Steve Malsam on 2/26/24.
//  Copyright © 2024 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface NRMAUIViewDetails : NSObject

@property (nonatomic, assign) NSInteger viewId;
@property (nonatomic, assign) CGRect frame;
@property (nonatomic, strong) UIColor* backgroundColor;
@property (nonatomic, assign) BOOL isHidden;
@property (nonatomic, assign) CGFloat cornerRadius;
@property (nonatomic, assign) CGFloat borderWidth;
@property (nonatomic, strong) UIColor* borderColor;
@property (nonatomic, strong) NSString* viewName;
@property (nonatomic, strong) NSMutableArray<NRMAUIViewDetails *>* childViews;

- (instancetype)initWithView:(UIView *)view;
- (NSDictionary *)jsonDescription;
- (NSString *)cssDescription;
- (NSString *)generateBaseCSSStyle;

+ (NSString *)colorToString:(UIColor *)color includingAlpha:(BOOL)includingAlpha;
@end

NS_ASSUME_NONNULL_END

