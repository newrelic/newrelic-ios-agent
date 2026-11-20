//
//  NRMAMaskingTestConfiguration.h
//  Agent
//
//  Test-only helper that makes +[NRMAHarvestController configuration] return a
//  configuration the test controls, without starting the agent or the network.
//

#import <Foundation/Foundation.h>
#import "NRMAHarvesterConfiguration.h"

@interface NRMAMaskingTestConfiguration : NSObject
/// Installs a fresh configuration and returns it so the test can adjust its masking settings.
+ (NRMAHarvesterConfiguration* _Nonnull) install;
/// Restores the harvest controller that was installed before +install.
+ (void) uninstall;
@end
