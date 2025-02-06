//
//  NRMAUIImageViewDetails.m
//  Agent_iOS
//
//  Created by Steve Malsam on 10/7/24.
//  Copyright © 2024 New Relic. All rights reserved.
//

#import "NRMAUIImageViewDetailsObjC.h"

@implementation NRMAUIImageViewDetailsObjC

- (NSString *)cssDescription {
    NSString *cssSelector = [self generateViewCSSSelector];
    
    NSString *cssStyle = [super generateBaseCSSStyle];
    
    cssStyle = [cssStyle stringByAppendingString:@"background: rgb(2,0,36);background: linear-gradient(90deg, rgba(2,0,36,1) 0%, rgba(0,212,255,1) 100%);"];
    
    return [NSString stringWithFormat:@"#%@ { %@ }",
            cssSelector, cssStyle];
}

- (NSString *)generateViewCSSSelector {
    return [NSString stringWithFormat:@"%@-%@", self.viewName, [@(self.viewId) stringValue]];
}


@end
