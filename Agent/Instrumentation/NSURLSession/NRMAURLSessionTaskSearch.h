 //
//  NRMAURLSessionTaskSearch.h
//  NewRelicAgent
//
//  Created by Chris Dillard on 12/6/22.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NRMAURLSessionTaskSearch: NSObject

+ (NSArray<Class> *)urlSessionTaskClasses;

@end

NS_ASSUME_NONNULL_END
