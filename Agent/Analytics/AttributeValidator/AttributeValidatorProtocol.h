//
//  AttributeValidatorProtocol.h
//  Agent
//
//  Created by Steve Malsam on 6/15/23.
//  Copyright © 2023 New Relic. All rights reserved.
//

#ifndef AttributeValidatorProtocol_h
#define AttributeValidatorProtocol_h

typedef BOOL (^NameValidator)(NSString*);
typedef BOOL (^ValueValidator)(id);
typedef BOOL (^EventTypeValidator)(NSString*);

@protocol AttributeValidatorProtocol <NSObject>

- (BOOL)nameValidator:(NSString *)name;
- (BOOL)valueValidator:(id)value;
- (BOOL)eventTypeValidator:(NSString *)eventType;

@end

#endif /* AttributeValidatorProtocol_h */
