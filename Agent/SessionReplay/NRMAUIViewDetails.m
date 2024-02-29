//
//  NRMAUIViewDetails.m
//  Agent_iOS
//
//  Created by Steve Malsam on 2/26/24.
//  Copyright © 2024 New Relic. All rights reserved.
//

#import "NRMAUIViewDetails.h"

@implementation NRMAUIViewDetails

- (instancetype)initWithView:(UIView *)view {
    self = [super init];
    if(self) {
        _frame = view.frame;
        _backgroundColor = view.backgroundColor;
        _isHidden = view.isHidden;
        _viewName = NSStringFromClass([view class]);
    }
    return self;
}

- (NSString *)description {
    //    NSString *descriptionString = [NSString stringWithFormat:@"View: %@\n\tFrame: %@\n\tBackground Color: %@", self.viewName, frameString, colorString];"
    NSMutableString *descriptionString = [NSMutableString stringWithFormat:@"View: %@\n", self.viewName];
    NSString *frameString = [NSString stringWithFormat:@"View Frame: {%f, %f}, {%f, %f}",
                             self.frame.origin.x, self.frame.origin.y,
                             self.frame.size.width, self.frame.size.height];
//    [descriptionString stringByAppendingFormat:@"\t%@\n", frameString];
    [descriptionString appendFormat:@"\t%@\n", frameString];
    
    if(self.backgroundColor != nil) {
        CGFloat *colorComponents = CGColorGetComponents(self.backgroundColor.CGColor);
        NSString *colorString = [NSString stringWithFormat:@"Background Color: %f, %f, %f",
                                 colorComponents[0],
                                 colorComponents[1],
                                 colorComponents[2],
                                 colorComponents[3]];
        [descriptionString appendFormat:@"\t%@", colorString];
    }
    
    return descriptionString;
}

- (NSDictionary *)jsonDescription {
    
    NSMutableDictionary *jsonDictionary = [[NSMutableDictionary alloc] init];
    jsonDictionary[@"frame"] = NSStringFromCGRect(self.frame);
    jsonDictionary[@"isHidden"] = @(self.isHidden);
    jsonDictionary[@"name"] = self.viewName;
    
    if(self.backgroundColor != nil) {
        CGFloat *colorComponents = CGColorGetComponents(self.backgroundColor.CGColor);
        NSString *colorString = [NSString stringWithFormat:@"%f, %f, %f",
                                 colorComponents[0],
                                 colorComponents[1],
                                 colorComponents[2],
                                 colorComponents[3]];
        jsonDictionary[@"backgroundColor"] = colorString;
    }
    return jsonDictionary;
}
@end
