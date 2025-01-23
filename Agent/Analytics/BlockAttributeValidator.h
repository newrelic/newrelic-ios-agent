//
//  BlockAttributeValidator.h
//  Agent
//
//  Created by Steve Malsam on 6/15/23.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "AttributeValidatorProtocol.h"

NS_ASSUME_NONNULL_BEGIN

@interface BlockAttributeValidator : NSObject <AttributeValidatorProtocol>

@property (copy, readonly) NameValidator nameValidator;
@property (copy, readonly) ValueValidator valueValidator;
@property (copy, readonly) EventTypeValidator eventTypeValidator;

- (instancetype)initWithNameValidator:(NameValidator)nameValidator
                       valueValidator:(ValueValidator)valueValidator
                andEventTypeValidator:(EventTypeValidator)eventTypeValidator;

+ (BlockAttributeValidator *) attributeValidator;

@end

NS_ASSUME_NONNULL_END
