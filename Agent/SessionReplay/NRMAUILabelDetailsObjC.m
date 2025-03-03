//
//  NRMAUILabelDetails.m
//  Agent_iOS
//
//  Created by Steve Malsam on 2/29/24.
//  Copyright © 2024 New Relic. All rights reserved.
//

#import "NRMAUILabelDetailsObjC.h"
#import "NRMAIdGeneratorObjC.h"
#import "NRMAUIViewDetailsObjC.h"

@implementation NRMAUILabelDetailsObjC

- (instancetype)initWithView:(UIView *)view {
    self = [super initWithView:view];
    if(self) {
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
    NSDictionary *textNode = @{
        @"type": @(3),
        @"textContent": self.labelText,
        @"id": @([NRMAIdGeneratorObjC generateID])
    };
    [subviews addObject:textNode];

    jsonDictionary[@"childNodes"] = subviews;
    jsonDictionary[@"id"] = @(self.viewId);
    
    return jsonDictionary;
}

- (NSString *)cssDescription {
    NSString *cssSelector = [self generateViewCSSSelector];
    
    NSString *cssStyle = [super generateBaseCSSStyle];
    
    cssStyle = [cssStyle stringByAppendingFormat:@"white-space: pre-wrap; font: %.2fpx %@;",
     self.fontSize, self.fontFamily];
    
    if(self.textColor) {
        NSString *textColorString = [NRMAUIViewDetailsObjC colorToString:self.textColor includingAlpha:YES];
        cssStyle = [cssStyle stringByAppendingFormat:@"color: %@;", textColorString];
    }
    
    return [NSString stringWithFormat:@"#%@ { %@ }",
            cssSelector, cssStyle];
}

- (NSString *)generateViewCSSSelector {
    return [NSString stringWithFormat:@"%@-%@", self.viewName, [@(self.viewId) stringValue]];
}

@end

