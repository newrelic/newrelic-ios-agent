//
//  NRMATrace.h
//  NewRelicAgent
//
//  Created by Bryce Buchanan on 9/9/13.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NRMAConsumerProtocol.h"
#import "NRMACustomTrace.h"
@class  NRMATraceMachine;
#import "NRMAThreadInfo.h"
@interface NRMATrace : NSObject <NRMAConsumerProtocol>
@property(nonatomic,assign) double entryTimestamp;
@property(nonatomic,assign) double exitTimestamp;
// atomic: name/classLabel/methodLabel feed -metricName, which is read on background
// trace-completion threads while these are set on other threads. A nonatomic getter
// would hand back an unretained pointer a concurrent setter can free before ARC retains it.
@property(atomic,strong) NSString* name;
@property(atomic,strong) NSString* classLabel;
@property(atomic,strong) NSString* methodLabel;
// atomic: threadInfo.identity is read on background trace-completion threads (completeTrace:).
@property(atomic,strong) NRMAThreadInfo* threadInfo;
/// Identity of the interaction (activity trace) this segment belongs to.
///
/// Duplicated here rather than read through `traceMachine.activityTrace.interactionId` because
/// `traceMachine` is a weak reference: once an interaction completes and its machine is released,
/// that chain reads nil, and the thread-local store still needs the id to find and unwind the
/// segment stack this trace was pushed onto. Assigned once at creation and never mutated.
@property(atomic,strong) NSString* interactionId;
@property(nonatomic,strong) NSMutableDictionary* parameters;
@property(nonatomic,assign) BOOL      persistent;
@property(nonatomic,strong) NSMutableSet* children; 
@property(atomic,weak)   NRMATraceMachine* traceMachine;
@property(nonatomic,strong)    NSMutableArray* scopedMeasurements;
@property(nonatomic,readonly) double exclusiveTimeMillis;
@property(nonatomic,readonly) double networkTimeMillis;
@property(nonatomic) enum NRTraceType category;
@property(nonatomic) BOOL   ignoreNode;
- (id) init;
- (id) initWithName:(NSString*)name
       traceMachine:(NRMATraceMachine*)traceMachine;

- (NSTimeInterval) durationInSeconds;
- (NSString*) metricName;
- (void) complete;
- (void) addChild:(NRMATrace*)trace;
- (void) calculateExclusiveTime;
@end
