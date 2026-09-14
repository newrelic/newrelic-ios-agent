//
//  NRMAInteractionHistory.h
//  NewRelicAgent
//
//  Created by Bryce Buchanan on 5/19/14.
//  Copyright © 2023 New Relic. All rights reserved.
//

#ifndef NewRelicAgent_NRMAInteractionHistory_h
#define NewRelicAgent_NRMAInteractionHistory_h

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// The interaction history is the breadcrumb trail the crash handler writes into
// the crash metadata file, so its read path has to be async-signal-safe: no
// allocation, no locks, no Objective-C. It is backed by a fixed ring of
// fixed-size records that writers fill in place and publish with atomic stores.
//
// This replaces a malloc'd singly-linked list, which could not be read safely
// from a signal handler: walking it raced concurrent inserts, and tearing it
// down called free(), which is not async-signal-safe and can deadlock the
// handler outright if the crash happened while any thread held the malloc lock.
// The list also grew without bound for as long as the process lived.
//
// Recycling the oldest record once the ring is full bounds both the memory the
// history occupies and the time the crash handler spends serializing it.

#define NRMA_INTERACTION_HISTORY_CAPACITY 64
#define NRMA_INTERACTION_NAME_CAPACITY   127

/// A consistent view of the ring taken at one instant. Entry 0 is the newest
/// interaction, entry (count - 1) the oldest still retained. Inserts that land
/// after a snapshot is taken never renumber it; they can only recycle its
/// oldest entries, which then read back as absent.
typedef struct {
    uint32_t newest; ///< sequence number of entry 0; 0 when the ring is empty
    uint32_t count;  ///< number of readable entries in this snapshot
} NRMAInteractionHistorySnapshot;

/// Records an interaction, recycling the oldest entry once the ring is full.
/// Names are truncated to NRMA_INTERACTION_NAME_CAPACITY; NULL and empty names
/// are ignored. Safe to call from any thread. Takes a lock, so it must not be
/// called from a signal handler.
void NRMA__AddInteraction(const char* interactionName, long long timestampMillis);

/// Takes a snapshot of the history. Async-signal-safe.
NRMAInteractionHistorySnapshot NRMA__snapshotInteractionHistory(void);

/// Copies entry `index` of `snapshot` into the caller's buffer, newest first.
/// Returns false if the index is out of range or if the entry was recycled
/// before it could be read coherently. On success `nameOut` is NUL-terminated
/// and `timestampMillisOut`, when non-NULL, belongs to the same interaction as
/// the copied name. Async-signal-safe.
bool NRMA__readInteraction(NRMAInteractionHistorySnapshot snapshot,
                           uint32_t index,
                           char* nameOut,
                           size_t nameOutSize,
                           long long* timestampMillisOut);

/// Drops every retained interaction. Async-signal-safe.
void NRMA__clearInteractionHistory(void);

#ifdef __cplusplus
}
#endif

#endif // NewRelicAgent_NRMAInteractionHistory_h
