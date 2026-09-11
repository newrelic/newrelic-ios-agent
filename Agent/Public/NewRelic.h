//
//  New Relic for Mobile -- iOS edition
//
//  See:
//    https://docs.newrelic.com/docs/mobile-monitoring for information
//    https://docs.newrelic.com/docs/release-notes/mobile-release-notes/xcframework-release-notes/ for release notes
//
//  Copyright © 2023 New Relic. All rights reserved.
//  See https://docs.newrelic.com/docs/licenses/ios-agent-licenses for license details
//

/*
 *  This document describes various APIs available to further customize New Relic's
 *  data collection. NewRelic's implementation lives in NewRelic.swift; this header
 *  re-exports its generated Objective-C interface plus the supporting declaration
 *  headers so `#import <NewRelic/NewRelic.h>` keeps working unchanged.
 */

#import <NewRelic/NewRelicFeatureFlags.h>
#import <NewRelic/NRConstants.h>
#import <NewRelic/NRTimer.h>
#import <NewRelic/NRLogger.h>
#import <NewRelic/NewRelicCustomInteractionInterface.h>
#import <NewRelic/NRGCDOverride.h>

// This header is itself transitively included by the framework's own umbrella header
// (Agent.h), which Swift must resolve via "-import-underlying-module" while compiling
// NewRelic.swift — before NewRelic-Swift.h has been generated. Guarding with
// __has_include breaks that circular self-import: the include is skipped while the
// Clang module for the underlying ObjC target is first being built, and picked up
// normally once the generated header exists (e.g. for external framework consumers).
#if __has_include(<NewRelic/NewRelic-Swift.h>)
#import <NewRelic/NewRelic-Swift.h>
#endif

/*******************************************************************************
 * Helper macros for +[NewRelic startInteractionWithName:], +[NewRelic
 * stopCurrentInteraction:], +[NewRelic startTracingMethod:object:timer:category:],
 * and +[NewRelic endTracingMethodWithTimer:]. Preserved verbatim from the original
 * NewRelic.h so existing callers of these macros keep compiling unchanged.
 ******************************************************************************/

#ifdef __cplusplus
extern "C" {
#endif

#define NR_START_NAMED_INTERACTION(name) [NewRelic startInteractionWithName:name]
#define NR_INTERACTION_STOP(interactionIdentifier) [NewRelic stopCurrentInteraction:interactionIdentifier]
#define NR_TRACE_METHOD_START(traceCategory)  NRTimer *__nr__trace__timer = [[NRTimer alloc] init]; [NewRelic startTracingMethod:_cmd object:self timer:__nr__trace__timer category:traceCategory];
#define NR_TRACE_METHOD_STOP   [NewRelic endTracingMethodWithTimer:__nr__trace__timer]; __nr__trace__timer = nil;
#define NR_NONARC_TRACE_METHOD_STOP   [NewRelic endTracingMethodWithTimer:__nr__trace__timer]; [__nr__trace__timer release];__nr__trace__timer = nil;

#ifdef __cplusplus
}
#endif
