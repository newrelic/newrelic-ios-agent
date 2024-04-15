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
        _frame = [view convertRect:view.frame toCoordinateSpace:view.window.screen.fixedCoordinateSpace];
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
    jsonDictionary[@"frame"] = NSStringFromCGRect(self.frame);
    jsonDictionary[@"isHidden"] = @(self.isHidden);
    jsonDictionary[@"name"] = self.viewName;
    jsonDictionary[@"textContent"] = self.labelText;
    jsonDictionary[@"id"] = @(self.viewId);
    jsonDictionary[@"type"] = @(3);
    
    NSString *textColor = [NRMAUIViewDetails colorToString:self.textColor includingAlpha:YES];
    jsonDictionary[@"textColor"] = textColor;
    
    NSMutableDictionary *attributesDictionary = [[NSMutableDictionary alloc] init];

    NSString *frameString = [NSString stringWithFormat:@"position:absolute;top:%fpx;left:%fpx;width:%f;height:%f", self.frame.origin.x,
                             self.frame.origin.y,
                             self.frame.size.width,
                             self.frame.size.height];
    
    frameString = [frameString stringByAppendingFormat:@";color:%@", textColor];
    
    frameString = [frameString stringByAppendingFormat:@";font: %fpt %@", self.fontSize, self.fontFamily];
    
    if(self.backgroundColor != nil) {
        NSString *colorString = [NRMAUIViewDetails colorToString:self.backgroundColor includingAlpha:YES];
        jsonDictionary[@"backgroundColor"] = colorString;
        frameString = [frameString stringByAppendingFormat:@";background-color:%@", colorString];
    }
    
    attributesDictionary[@"style"] = frameString;
    jsonDictionary[@"attributes"] = attributesDictionary;
    
    return jsonDictionary;
}

@end

