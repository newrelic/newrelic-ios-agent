//
//  NRMASAM.m
//  Agent
//
//  Created by Steve Malsam on 8/10/23.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import "NRMASAM.h"
#import "NRMAJSON.h"

@implementation NRMASAM {
    NSMutableDictionary<NSString *, id>* attributes;
}

- (instancetype)init {
    self = [super init];
    if(self) {
        attributes = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (BOOL)setSessionAttribute:(nonnull NSString *)name value:(nonnull id)value {
    @synchronized (attributes) {
        attributes[name] = value;
    }
    
    return YES;
}


- (nullable NSString *)getSessionAttributeJSONStringWithError:(NSError * _Nullable __autoreleasing * _Nullable)error {
    
    NSData *attributeJsonData = [NRMAJSON dataWithJSONObject:attributes
                                                     options:0
                                                       error:&error];
    NSString *attributeJsonString = [[NSString alloc] initWithData:attributeJsonData
                                                          encoding:NSUTF8StringEncoding];
    
    return attributeJsonString;
}

@end
