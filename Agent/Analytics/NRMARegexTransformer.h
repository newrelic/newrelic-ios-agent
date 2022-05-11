//
//  NRMARegexTransformer.h
//  Agent
//
//  Created by Steve Malsam on 5/5/22.
//  Copyright © 2022 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NRMANetworkRequestData.h"

NS_ASSUME_NONNULL_BEGIN

@interface NRMARegexTransformer : NSObject

- (instancetype) initWithRegexRules:(NSDictionary<NSString *, NSString *>*)regexRules;

- (NSURL *)transformURL:(NSURL *)url;

@end

NS_ASSUME_NONNULL_END
