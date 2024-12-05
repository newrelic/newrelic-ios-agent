//
//  NRMAUIViewDetails.m
//  Agent_iOS
//
//  Created by Steve Malsam on 2/26/24.
//  Copyright © 2024 New Relic. All rights reserved.
//

#import "NRMAUIViewDetails.h"

#import "NRMAAssociate.h"
#import "NRMAIdGenerator.h"

@implementation NRMAUIViewDetails

- (instancetype)initWithView:(UIView *)view {
    self = [super init];
    if(self) {
        _frame = [view.superview convertRect:view.frame toCoordinateSpace:view.window.screen.fixedCoordinateSpace];
//        _frame = view.frame;
        _backgroundColor = view.backgroundColor;
        _isHidden = view.isHidden;
        _cornerRadius = view.layer.cornerRadius;
        _borderWidth = view.layer.borderWidth;
        _borderColor = [UIColor colorWithCGColor:view.layer.borderColor];
        _viewName = NSStringFromClass([view class]);
//        _viewId = [NRMAIdGenerator generateID];
        _childViews = [[NSMutableArray alloc] init];
        
        id associatedId = [NRMAAssociate retrieveFrom:view with:@"SessionReplayID"];
        if(associatedId) {
            _viewId = [((NSNumber *)associatedId) intValue];
        } else {
            _viewId = [NRMAIdGenerator generateID];
            [NRMAAssociate attach:@(_viewId) to:view with:@"SessionReplayID"];
        }
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
    NSMutableString *cssStyle = [NSMutableString stringWithFormat:@"position: fixed;left: %.2fpx;top: %.2fpx;width: %.2fpx;height: %.2fpx;",
                          self.frame.origin.x,
                          self.frame.origin.y,
                          self.frame.size.width,
                          self.frame.size.height];
    
    if(self.backgroundColor) {
        NSString *backgroundColorString = [NRMAUIViewDetails colorToString:self.backgroundColor includingAlpha:YES];
        [cssStyle appendFormat:@"background-color: %@;", backgroundColorString];
    }

    if(self.borderWidth > 0) {
        //border: 4mm ridge rgba(211, 220, 50, .6);
        [cssStyle appendFormat:@"border-radius: %.2fpx;", self.cornerRadius];
        NSString *borderColorString = [NRMAUIViewDetails colorToString:[UIColor colorWithWhite:0.0 alpha:0.5] includingAlpha:YES];
        [cssStyle appendFormat:@"border: %.2fpx solid %@", self.borderWidth, borderColorString];
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
    
    CGColorRef colorRef = color.CGColor;
    
    // We're dealing with a grayscale color. Either White, Black,
    // or some grey in between
    if(CGColorGetNumberOfComponents(colorRef) == 2) {
        CGFloat *colorComponents = CGColorGetComponents(colorRef);
        
        redColor = colorComponents[0];
        blueColor = colorComponents[0];
        greenColor = colorComponents[0];
        alpha = colorComponents[1];
    } else { // regular 4 component color;
        BOOL success = NO;
        success = [color getRed:&redColor
                          green:&greenColor
                           blue:&blueColor
                          alpha:&alpha];
        
        if(!success) {
            NSLog(@"ERROR: UNABLE TO GET COLOR INFO");
        }
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
