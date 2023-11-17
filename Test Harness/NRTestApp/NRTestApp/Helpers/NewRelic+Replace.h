//
//  NewRelic+Replace.h
//  NRTestApp
//
//  Created by Chris Dillard on 10/17/23.
//

#import <NewRelic/NewRelic.h>

@interface NewRelic (Replace)
+ (void) replaceDeviceIdentifier:(NSString*)identifier;
@end
