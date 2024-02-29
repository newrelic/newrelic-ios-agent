//
//  NRMAUILabelDetails.m
//  Agent_iOS
//
//  Created by Steve Malsam on 2/29/24.
//  Copyright © 2024 New Relic. All rights reserved.
//

#import "NRMAUILabelDetails.h"

@implementation NRMAUILabelDetails

- (instancetype)initWithView:(UIView *)view {
    self = [super init];
    if(self) {
        _frame = view.frame;
        _backgroundColor = view.backgroundColor;
        _isHidden = view.isHidden;
        _viewName = NSStringFromClass([view class]);
        _labelText = [@"" stringByPaddingToLength:((UILabel*)view).text.length
                                       withString:@"x"
                                  startingAtIndex:0];
        _textColor = ((UILabel *)view).textColor;
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
        
        [descriptionString appendFormat:@"\tText: %@", self.labelText];
        
        CGFloat *textColorComponents = CGColorGetComponents(self.textColor.CGColor);
        NSString *textColor = [NSString stringWithFormat:@"Text Color: %f, %f, %f",
                               textColorComponents[0],
                               textColorComponents[1],
                               textColorComponents[2],
                               textColorComponents[3]];
        [descriptionString appendFormat:@"\t%@", textColor];
    }
    
    return descriptionString;
}

- (NSDictionary *)jsonDescription {
    CGFloat *backgroundColorComponents = CGColorGetComponents(self.backgroundColor.CGColor);
    NSString *backgroundColor = [NSString stringWithFormat:@"%f, %f, %f",
                             backgroundColorComponents[0],
                             backgroundColorComponents[1],
                             backgroundColorComponents[2],
                             backgroundColorComponents[3]];
    
    CGFloat *textColorComponents = CGColorGetComponents(self.textColor.CGColor);
    NSString *textColor = [NSString stringWithFormat:@"%f, %f, %f",
                           textColorComponents[0],
                           textColorComponents[1],
                           textColorComponents[2],
                           textColorComponents[3]];
    
    NSDictionary *jsonDictionary = @{@"frame":NSStringFromCGRect(self.frame),
                                     @"backgroundColor":backgroundColor,
                                     @"isHidden":@(self.isHidden),
                                     @"name":self.viewName,
                                     @"text":self.labelText,
                                     @"textColor":textColor};
    return jsonDictionary;
}

@end

