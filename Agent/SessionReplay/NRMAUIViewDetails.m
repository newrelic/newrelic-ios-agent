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
    NSMutableString *descriptionString = [NSMutableString stringWithFormat:@"View: %@\n, id: %ld", self.viewName, (long)self.viewId];
    NSString *frameString = [NSString stringWithFormat:@"View Frame: {%f, %f}, {%f, %f}",
                             self.frame.origin.x, self.frame.origin.y,
                             self.frame.size.width, self.frame.size.height];
//    [descriptionString stringByAppendingFormat:@"\t%@\n", frameString];
    [descriptionString appendFormat:@"\t%@\n", frameString];
    
    if(self.backgroundColor != nil) {
        NSString *colorString = [NRMAUIViewDetails colorToString:self.backgroundColor includingAlpha:YES];
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
    jsonDictionary[@"frame"] = CFBridgingRelease(CGRectCreateDictionaryRepresentation(self.frame));
    jsonDictionary[@"backgroundColor"] = [NRMAUIViewDetails colorToString:self.backgroundColor includingAlpha:YES];
    
//    NSMutableDictionary *attributesDictionary = [[NSMutableDictionary alloc] init];
//
//    NSString *frameString = [NSString stringWithFormat:@"position:absolute;top:%fpx;left:%fpx;width:%fpx;height:%fpx", self.frame.origin.y,
//                             self.frame.origin.x,
//                             self.frame.size.width,
//                             self.frame.size.height];
//    
//    if(self.backgroundColor != nil) {
//        NSString *colorString = [NRMAUIViewDetails colorToString:self.backgroundColor includingAlpha:YES];
//        jsonDictionary[@"backgroundColor"] = colorString;
//        frameString = [frameString stringByAppendingFormat:@";background-color:%@", colorString];
//    }
//    
//    attributesDictionary[@"style"] = frameString;
//    jsonDictionary[@"attributes"] = attributesDictionary;
    
    return jsonDictionary;
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
    
//    CGFloat *colorComponents = CGColorGetComponents(color);
//    NSString *colorFormatString = @"#%02lX%02lX%02lX";
//    NSString *colorString = @"";
    if(includingAlpha) {
        colorFormatString = [colorFormatString stringByAppendingString:@"%02lX"];
        colorString = [NSString stringWithFormat:colorFormatString,
                       lroundf(redColor * 255),
                       lroundf(blueColor * 255),
                       lroundf(greenColor * 255),
                       lroundf(alpha * 255)];
    } else {
        NSString *colorString = [NSString stringWithFormat:colorFormatString,
                                 lroundf(redColor * 255),
                                 lroundf(greenColor * 255),
                                 lroundf(blueColor * 255)];
    }
    
    return colorString;
}
@end
