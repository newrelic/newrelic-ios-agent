//
//  NRMAUIViewDetails.m
//  Agent_iOS
//
//  Created by Steve Malsam on 2/26/24.
//  Copyright © 2024 New Relic. All rights reserved.
//

#import "NRMAUIViewDetails.h"
#import "NRMAIdGenerator.h"

@implementation NRMAUIViewDetails

- (instancetype)initWithView:(UIView *)view {
    self = [super init];
    if(self) {
        _frame = [view.superview convertRect:view.frame toCoordinateSpace:view.window.screen.fixedCoordinateSpace];
//        _frame = view.frame;
        _backgroundColor = view.backgroundColor;
        _isHidden = view.isHidden;
        _viewName = NSStringFromClass([view class]);
        _viewId = [NRMAIdGenerator generateID];
        _childViews = [[NSMutableArray alloc] init];
    }
    return self;
}

- (NSDictionary *)jsonDescription {
    NSMutableDictionary *jsonDictionary = [[NSMutableDictionary alloc] init];
    jsonDictionary[@"type"] = @(2);
    jsonDictionary[@"tagName"] = @"div";
    jsonDictionary[@"attributes"] = @{
        @"id": [self generateViewCSSSelector]
    };
    
    NSMutableArray *subviews = [[NSMutableArray alloc] init];
    
    jsonDictionary[@"childNodes"] = subviews;
    jsonDictionary[@"id"] = @(self.viewId);
    
    return jsonDictionary;
}

- (NSString *)generateBaseCSSStyle {
    NSString *cssStyle = [NSString stringWithFormat:@"position: fixed;left: %.2fpx;top: %.2fpx;width: %.2fpx;height: %.2fpx;",
                          self.frame.origin.x,
                          self.frame.origin.y,
                          self.frame.size.width,
                          self.frame.size.height];
    
    if(self.backgroundColor) {
        NSString *backgroundColorString = [NRMAUIViewDetails colorToString:self.backgroundColor includingAlpha:YES];
        cssStyle = [cssStyle stringByAppendingFormat:@"background-color: %@;", backgroundColorString];
    }
    return cssStyle;
}

- (NSString *)cssDescription {
    NSString *cssSelector = [self generateViewCSSSelector];
    
    NSString * cssStyle = [self generateBaseCSSStyle];

    
    return [NSString stringWithFormat:@"#%@ { %@ }",
            cssSelector, cssStyle];
}

- (NSString *)generateViewCSSSelector {
    return [NSString stringWithFormat:@"%@-%@", self.viewName, [@(self.viewId) stringValue]];
}

+ (NSString *)colorToString:(UIColor *)color includingAlpha:(BOOL)includingAlpha {
    CGFloat redColor = 0.0f;
    CGFloat blueColor = 0.0f;
    CGFloat greenColor = 0.0f;
    CGFloat alpha = 0.0f;
    
    BOOL success = NO;
    success = [color getRed:&redColor
                      green:&greenColor
                       blue:&blueColor
                      alpha:&alpha];
    
    if(!success) {
        NSLog(@"ERROR: UNABLE TO GET COLOR INFO");
    }
    
    NSString *colorFormatString = @"#%02lX%02lX%02lX";
    NSString *colorString = @"";

    if(includingAlpha) {
        colorFormatString = [colorFormatString stringByAppendingString:@"%02lX"];
        colorString = [NSString stringWithFormat:colorFormatString,
                       lroundf(redColor * 255),
                       lroundf(greenColor * 255),
                       lroundf(blueColor * 255),
                       lroundf(alpha * 255)];
    } else {
        colorString = [NSString stringWithFormat:colorFormatString,
                                 lroundf(redColor * 255),
                                 lroundf(greenColor * 255),
                                 lroundf(blueColor * 255)];
    }
    
    return colorString;
}
@end
