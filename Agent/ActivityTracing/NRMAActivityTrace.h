//
//  NRMAActivityTrace.h
//  NewRelicAgent
//
//  Created by Bryce Buchanan on 9/6/13.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import "NRMATrace.h"
#import "NRMAInteractionDataStamp.h"

@interface NRMAActivityTrace : NSObject
@property(nonatomic,strong) NSMutableDictionary* traces;

//used to identify the original object that initiated the activity trace
//generally just the memory address of the object. 
// atomic: read cross-thread (e.g. -isInteractionObject:) while mutated under kNRMAStartAndEndTracingLock.
@property(atomic,strong) NSString          *initiatingObjectIdentifier;
// atomic: read on background trace-completion threads (completeTrace:) while set during setup.
@property(atomic,strong) NRMATrace         *rootTrace;
@property(atomic,strong) NSMutableSet    *missingChildren;
@property(nonatomic,assign) double      lastUpdated;
@property(atomic,assign)    BOOL            isComplete;
// atomic: name/type are read on background completion threads (getCurrentActivityName)
// while being replaced on other threads; a nonatomic getter would return an
// unretained pointer that a concurrent setter can free before ARC retains it.
@property(atomic,strong) NSString        *type;
@property(atomic,strong) NSString        *name;
// Identity of this interaction, used to join the interaction event against the MobileView events
// emitted while it runs. Assigned once at trace creation; atomic for the same reason as name/type.
@property(atomic,strong) NSString        *interactionId;
@property(nonatomic,strong) NSMutableDictionary *memoryVitals;
@property(nonatomic,strong) NSMutableDictionary *cpuVitals;
@property(nonatomic)        double          totalExclusiveTimeMillis;
@property(nonatomic)        double          totalNetworkTimeMillis;
@property(nonatomic)        NSUInteger       nodes;
@property(nonatomic)         double       startTime; //milliseconds
@property(nonatomic)         double       endTime;   //milliseconds
@property(strong)   NRMAInteractionDataStamp* lastActivityStamp;

- (id) initWithRootTrace:(NRMATrace*)rootTrace;
- (void) addTrace:(NRMATrace*)trace;
- (BOOL) hasMissingChildren;
/// Completes the trace, ending it at `lastUpdated` — the last instrumented method boundary.
/// This is quiescence semantics: the interaction ended when work stopped, not when the trace
/// machine's timer noticed, so the timeout never inflates the reported duration.
- (void) complete;
/// Completes the trace, ending it at an explicit wall-clock timestamp. Used when something other
/// than the quiescence timer ends the interaction (an explicit `stopCurrentInteraction:`, or
/// supersession by the next screen's interaction), where the real end time is known and is what
/// the caller means by the interaction's duration.
///
/// `endTimestampMillis` is floored at `lastUpdated`, so the reported duration can never be shorter
/// than the instrumented work it contains.
- (void) completeWithEndTimestampMillis:(double)endTimestampMillis;
- (void) recordVitalsThrottled;
- (NSTimeInterval) durationInSeconds;
- (BOOL) shouldRecord;
@end
