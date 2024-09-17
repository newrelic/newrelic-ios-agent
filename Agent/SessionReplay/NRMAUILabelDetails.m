//
//  NRMAUILabelDetails.m
//  Agent_iOS
//
//  Created by Steve Malsam on 2/29/24.
//  Copyright © 2024 New Relic. All rights reserved.
//

#import "NRMAUILabelDetails.h"
#import "NRMAIdGenerator.h"
#import "NRMAUIViewDetails.h"

@implementation NRMAUILabelDetails

- (instancetype)initWithView:(UIView *)view {
    self = [super init];
    if(self) {
//        _frame = [view.superview convertRect:view.frame toCoordinateSpace:view.window.screen.fixedCoordinateSpace];
//        _frame = [view convertRect:view.frame toCoordinateSpace:nil];
        _frame = view.frame;
//        API_AVAILABLE(ios(5.0)) UIWindow *extractedExpr = ((UIWindowScene *)[[UIApplication sharedApplication] connectedScenes].anyObject).windows.firstObject;
//        _frame = [view convertRect:view.frame toCoordinateSpace:extractedExpr.screen.fixedCoordinateSpace];
//        _frame = [view convertRect:view.frame toView:extractedExpr];
        _backgroundColor = view.backgroundColor;
        _isHidden = view.isHidden;
        _viewName = NSStringFromClass([view class]);
//        _labelText = [@"" stringByPaddingToLength:((UILabel*)view).text.length
//                                       withString:@"x"
//                                  startingAtIndex:0];
        _labelText = ((UILabel *)view).text;
        _textColor = ((UILabel *)view).textColor;
        _fontSize = ((UILabel *)view).font.pointSize;
        _fontName = ((UILabel *)view).font.fontName;
        if([_fontName hasPrefix:@"."] && (_fontName.length > 1)) {
            _fontName = [_fontName substringFromIndex:1];
        }
        _fontFamily = ((UILabel *)view).font.familyName;
        if([_fontFamily hasPrefix:@"."] && (_fontFamily.length > 1)) {
            _fontFamily = [_fontFamily substringFromIndex:1];
        }
        _viewId = [NRMAIdGenerator generateID];
    }
    return self;
}

- (NSString *)description {
    //    NSString *descriptionString = [NSString stringWithFormat:@"View: %@\n\tFrame: %@\n\tBackground Color: %@", self.viewName, frameString, colorString];"
    NSMutableString *descriptionString = [NSMutableString stringWithFormat:@"View: %@\n, id: %d", self.viewName, self.viewId];
    NSString *frameString = [NSString stringWithFormat:@"View Frame: {%f, %f}, {%f, %f}",
                             self.frame.origin.x, self.frame.origin.y,
                             self.frame.size.width, self.frame.size.height];
//    [descriptionString stringByAppendingFormat:@"\t%@\n", frameString];
    [descriptionString appendFormat:@"\t%@\n", frameString];
    
    if(self.backgroundColor != nil) {
        NSString *colorString = [NRMAUIViewDetails colorToString:self.backgroundColor includingAlpha:YES];
        [descriptionString appendFormat:@"\t%@", colorString];
        
        [descriptionString appendFormat:@"\tText: %@", self.labelText];
        
        CGFloat *textColorComponents = CGColorGetComponents(self.textColor.CGColor);
        NSString *textColor = [NSString stringWithFormat:@"#%02lX%02lX%02lX%02lX",
                               lroundf(textColorComponents[0] * 255),
                               lroundf(textColorComponents[1] * 255),
                               lroundf(textColorComponents[2] * 255),
                               lroundf(textColorComponents[3] * 255)];
        [descriptionString appendFormat:@"\t%@", textColor];
    }
    
    return descriptionString;
}

- (NSDictionary *)jsonDescription {
    NSMutableDictionary *jsonDictionary = [[NSMutableDictionary alloc] init];
    jsonDictionary[@"type"] = @(2);
    jsonDictionary[@"tagName"] = @"div";
    jsonDictionary[@"attributes"] = @{
        @"id": [self generateViewCSSSelector]
    };
    
    NSMutableArray *subviews = [[NSMutableArray alloc] init];
    NSDictionary *textNode = @{
        @"type": @(3),
        @"textContent": self.labelText
    };
    [subviews addObject:textNode];
    
//    for(id<NRMAViewDetailProtocol> subview in _childViews) {
//        [subviews addObject:subview.jsonDescription];
//    }

    jsonDictionary[@"childNodes"] = subviews;
    jsonDictionary[@"id"] = @(self.viewId);
    
    return jsonDictionary;
}

- (NSString *)cssDescription {
    NSString *cssSelector = [self generateViewCSSSelector];
    NSString *backgroundColorString = self.backgroundColor ? [NRMAUIViewDetails colorToString:self.backgroundColor includingAlpha:YES] : @"#000000";
    
    return [NSString stringWithFormat:@"#%@ { background-color: %@;\
position: relative;\
left: %fpx;\
top: %fpx;\
width: %fpx;\
height: %fpx;\
color: %@;\
font: %fem $(%@);\
}",
            cssSelector,
            backgroundColorString,
            self.frame.origin.x,
            self.frame.origin.y,
            self.frame.size.width,
            self.frame.size.height,
            self.textColor,
            self.fontSize, self.fontFamily];
}

- (NSString *)generateViewCSSSelector {
    return [NSString stringWithFormat:@"UILabel-%@", [@(self.viewId) stringValue]];
}

@end

