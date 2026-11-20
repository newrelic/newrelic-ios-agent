//
//  NRMAMaskingTestConfiguration.m
//  Agent
//

#import "NRMAMaskingTestConfiguration.h"
#import "NRMAHarvestController.h"
#import "NRMAHarvester.h"

@interface NRMAHarvestController (MaskingTestConfiguration)
- (void) setHarvester:(NRMAHarvester*)harvester;
+ (void) setHarvestController:(NRMAHarvestController*)harvestController;
@end

// Returns whatever configuration the test installed; never touches storage or the network.
@interface NRMAMaskingTestHarvester : NRMAHarvester
@property (nonatomic, strong) NRMAHarvesterConfiguration* installedConfiguration;
@end

@implementation NRMAMaskingTestHarvester
- (NRMAHarvesterConfiguration*) harvesterConfiguration
{
    return self.installedConfiguration;
}
@end

static NRMAHarvestController* previousController;

@implementation NRMAMaskingTestConfiguration

+ (NRMAHarvesterConfiguration*) install
{
    NRMAHarvesterConfiguration* configuration = [[NRMAHarvesterConfiguration alloc] init];
    NRMAMaskingTestHarvester* harvester = [[NRMAMaskingTestHarvester alloc] init];
    harvester.installedConfiguration = configuration;

    previousController = [NRMAHarvestController harvestController];
    NRMAHarvestController* controller = [[NRMAHarvestController alloc] init];
    [controller setHarvester:harvester];
    [NRMAHarvestController setHarvestController:controller];
    return configuration;
}

+ (void) uninstall
{
    [NRMAHarvestController setHarvestController:previousController];
    previousController = nil;
}

@end
