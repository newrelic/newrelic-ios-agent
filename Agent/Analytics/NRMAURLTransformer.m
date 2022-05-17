//
//  NRMARegexTransformer.m
//  Agent
//
//  Created by Steve Malsam on 5/5/22.
//  Copyright © 2022 New Relic. All rights reserved.
//

#import "NRMAURLTransformer.h"

@implementation NRMAURLTransformer {
    NSDictionary<NSString *, NSString *>* _regexRules;
}

- (instancetype)initWithRegexRules:(NSDictionary<NSString *,NSString *> *)regexRules {
    if (self = [super init]) {
        _regexRules = regexRules;
    }
    
    return self;
}

- (NSURL*) transformURL:(NSURL *)url {
    NSMutableString *modifiedURLString = url.absoluteString.mutableCopy;
    [_regexRules enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, NSString * _Nonnull obj, BOOL * _Nonnull stop) {
        NSError *error;
        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:key
                                                                               options:NSRegularExpressionCaseInsensitive
                                                                                 error:&error];
        [regex replaceMatchesInString:modifiedURLString
                              options:0
                                range:NSMakeRange(0, modifiedURLString.length)
                         withTemplate:obj];
    }];
    
    return [NSURL URLWithString:modifiedURLString];
}

@end
