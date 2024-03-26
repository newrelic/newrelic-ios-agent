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
        _frame = [view convertRect:view.frame toCoordinateSpace:view.window.screen.fixedCoordinateSpace];
        _backgroundColor = view.backgroundColor;
        _isHidden = view.isHidden;
        _viewName = NSStringFromClass([view class]);
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
        CGFloat *colorComponents = CGColorGetComponents(self.backgroundColor.CGColor);
        NSString *colorString = [NSString stringWithFormat:@"#%02lX%02lX%02lX%02lX",
                                 lroundf(colorComponents[0] * 255),
                                 lroundf(colorComponents[1] * 255),
                                 lroundf(colorComponents[2] * 255),
                                 lroundf(colorComponents[3] * 255)];
        [descriptionString appendFormat:@"\t%@", colorString];
    }
    
    return descriptionString;
}

- (NSDictionary *)jsonDescription {
    
    NSMutableDictionary *jsonDictionary = [[NSMutableDictionary alloc] init];
    jsonDictionary[@"frame"] = NSStringFromCGRect(self.frame);
    jsonDictionary[@"isHidden"] = @(self.isHidden);
    jsonDictionary[@"name"] = self.viewName;
    jsonDictionary[@"id"] = @(self.viewId);
    jsonDictionary[@"type"] = @(2);
    
    NSMutableDictionary *attributesDictionary = [[NSMutableDictionary alloc] init];

    NSString *frameString = [NSString stringWithFormat:@"position:absolute;top:%fpx;left:%fpx;width:%f;height:%f", self.frame.origin.x,
                             self.frame.origin.y,
                             self.frame.size.width,
                             self.frame.size.height];
    
    if(self.backgroundColor != nil) {
        CGFloat *colorComponents = CGColorGetComponents(self.backgroundColor.CGColor);
        NSString *colorString = [NSString stringWithFormat:@"#%02lX%02lX%02lX",
                                 lroundf(colorComponents[0] * 255),
                                 lroundf(colorComponents[1] * 255),
                                 lroundf(colorComponents[2] * 255)];
        jsonDictionary[@"backgroundColor"] = colorString;
        frameString = [frameString stringByAppendingFormat:@";background-color:%@", colorString];
    }
    
    attributesDictionary[@"style"] = frameString;
    jsonDictionary[@"attributes"] = attributesDictionary;
    
    return jsonDictionary;
}
@end
