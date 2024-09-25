//
//  NRMASessionReplayCapture.m
//  Agent_iOS
//
//  Created by Steve Malsam on 9/25/24.
//  Copyright © 2024 New Relic. All rights reserved.
//

#import "NRMASessionReplayCapture.h"
#import "NRMAUIViewDetails.h"
#import "NRMAUILabelDetails.h"

typedef id<NRMAViewDetailProtocol> Node;

@implementation NRMASessionReplayCapture

-(NSArray<id<NRMAViewDetailProtocol>>*)recordFromRootView:(UIView *)rootView {
    NSMutableArray<Node>* nodes = [NSMutableArray new];
    
    [self recursivelyRecordView:rootView withNodes:nodes];
    
    return nodes;
}

- (void)recursivelyRecordView:(UIView *)view withNodes:(NSMutableArray<Node>*)nodes {
    Node viewToRecord;
    if([view isKindOfClass:[UILabel class]]) {
        viewToRecord = [[NRMAUILabelDetails alloc] initWithView:view];
    } else {
        viewToRecord = [[NRMAUIViewDetails alloc] initWithView:view];
    }

    [nodes addObject:viewToRecord];
    
    for(UIView* subview in view.subviews) {
        [self recursivelyRecordView:subview withNodes:nodes];
    }
}

@end
