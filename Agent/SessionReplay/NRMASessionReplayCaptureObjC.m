//
//  NRMASessionReplayCapture.m
//  Agent_iOS
//
//  Created by Steve Malsam on 9/25/24.
//  Copyright © 2024 New Relic. All rights reserved.
//

#import "NRMASessionReplayCaptureObjC.h"
#import "NRMAUIViewDetailsObjC.h"
#import "NRMAUILabelDetailsObjC.h"
#import "NRMAUIImageViewDetailsObjC.h"


@implementation NRMASessionReplayCaptureObjC

-(NSArray<NRMAUIViewDetailsObjC *>*)recordFromRootView:(UIView *)rootView {
    NSMutableArray<NRMAUIViewDetailsObjC *>* nodes = [NSMutableArray new];
    
    [self recursivelyRecordView:rootView withNodes:nodes];
    
    return nodes;
}

- (void)recursivelyRecordView:(UIView *)view withNodes:(NSMutableArray<NRMAUIViewDetailsObjC *>*)nodes {
    NRMAUIViewDetailsObjC * viewToRecord;
    if([view isKindOfClass:[UILabel class]]) {
        viewToRecord = [[NRMAUILabelDetailsObjC alloc] initWithView:view];
    } else if ([view isKindOfClass:[UIImageView class]]){
        viewToRecord = [[NRMAUIImageViewDetailsObjC alloc] initWithView:view];
    } else {
        viewToRecord = [[NRMAUIViewDetailsObjC alloc] initWithView:view];
    }
    
    // Determine if the view that we have is one that should be recorded, or is a system view that is going to be culled.
    NSMutableArray<NRMAUIViewDetailsObjC *> *childNodes;
    if([self shouldRecordView:view]) {
        [nodes addObject:viewToRecord];
//        childNodes = viewToRecord.childViews;
//    } else {
//        childNodes = nodes;
    }

    
    for(UIView* subview in view.subviews) {
//        [self recursivelyRecordView:subview withNodes:childNodes];
        [self recursivelyRecordView:subview withNodes:nodes];

    }
}

- (BOOL)shouldRecordView:(UIView *)view {
    UIView* superview = view.superview;
    
    if(superview == nil) {
        return YES;
    }
    
    BOOL areFramesTheSame = CGRectEqualToRect(view.frame, superview.frame);
    BOOL isClear = (view.alpha == 0 || view.alpha == 1);
    
    if(areFramesTheSame && isClear) {
        return NO;
    }
    
    return YES;
}

@end
