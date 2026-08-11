//
//  NRMAInteractionHistory.c
//  NewRelicAgent
//
//  Created by Bryce Buchanan on 5/19/14.
//  Copyright © 2023 New Relic. All rights reserved.
//

#include <pthread.h>
#include <stdatomic.h>
#include <string.h>
#include "NRMAInteractionHistory.h"

// One ring slot. `sequence` is the 1-based insert number of the interaction the
// slot currently holds; 0 means the slot is empty or mid-write. Readers validate
// the sequence both before and after copying, so a slot recycled underneath them
// is discarded rather than reported with a name and timestamp from two different
// interactions.
typedef struct {
    _Atomic uint32_t sequence;
    long long timestampMillis;
    char name[NRMA_INTERACTION_NAME_CAPACITY + 1];
} NRMAInteractionRecord;

static NRMAInteractionRecord __records[NRMA_INTERACTION_HISTORY_CAPACITY];

// Total interactions recorded, which is also the sequence number of the newest
// record. Readers anchor their snapshot to it.
static _Atomic uint32_t __insertCount = 0;

// Serializes writers against each other so two threads cannot interleave bytes
// into the same slot. Deliberately never taken by a reader:
// NRMA__snapshotInteractionHistory and NRMA__readInteraction run inside the
// crash handler, where blocking on a mutex the crashed thread still holds would
// cost us the report.
static pthread_mutex_t __writerLock = PTHREAD_MUTEX_INITIALIZER;

static NRMAInteractionRecord* NRMA__recordForSequence(uint32_t sequence)
{
    return &__records[(sequence - 1) % NRMA_INTERACTION_HISTORY_CAPACITY];
}

void NRMA__AddInteraction(const char* interactionName, long long timestampMillis)
{
    if (interactionName == NULL || interactionName[0] == '\0') {
        return;
    }

    pthread_mutex_lock(&__writerLock);

    // Sequence numbers are 1-based because 0 marks an empty slot. Wrapping after
    // 2^32 inserts only shifts which slot a sequence maps to; it cannot make a
    // reader mistake one record for another, because the slot's own sequence is
    // what gets compared.
    uint32_t sequence = atomic_load_explicit(&__insertCount, memory_order_relaxed) + 1;
    if (sequence == 0) {
        sequence = 1;
    }

    NRMAInteractionRecord* record = NRMA__recordForSequence(sequence);

    // Retire the slot before touching its payload so a concurrent reader
    // discards it instead of reading a half-updated record.
    atomic_store_explicit(&record->sequence, 0, memory_order_release);

    size_t length = strnlen(interactionName, NRMA_INTERACTION_NAME_CAPACITY);
    memcpy(record->name, interactionName, length);
    record->name[length] = '\0';
    record->timestampMillis = timestampMillis;

    atomic_store_explicit(&record->sequence, sequence, memory_order_release);
    atomic_store_explicit(&__insertCount, sequence, memory_order_release);

    pthread_mutex_unlock(&__writerLock);
}

NRMAInteractionHistorySnapshot NRMA__snapshotInteractionHistory(void)
{
    uint32_t newest = atomic_load_explicit(&__insertCount, memory_order_acquire);

    NRMAInteractionHistorySnapshot snapshot;
    snapshot.newest = newest;
    snapshot.count = (newest < NRMA_INTERACTION_HISTORY_CAPACITY) ? newest
                                                                 : NRMA_INTERACTION_HISTORY_CAPACITY;
    return snapshot;
}

bool NRMA__readInteraction(NRMAInteractionHistorySnapshot snapshot,
                           uint32_t index,
                           char* nameOut,
                           size_t nameOutSize,
                           long long* timestampMillisOut)
{
    if (nameOut == NULL || nameOutSize == 0 || index >= snapshot.count) {
        return false;
    }

    uint32_t sequence = snapshot.newest - index; // newest first
    if (sequence == 0) {
        return false;
    }

    NRMAInteractionRecord* record = NRMA__recordForSequence(sequence);

    if (atomic_load_explicit(&record->sequence, memory_order_acquire) != sequence) {
        return false; // empty, mid-write, or already recycled
    }

    // The trailing byte of record->name is never written, so this copy is
    // bounded even if the slot is being recycled as we read it.
    size_t length = strnlen(record->name, NRMA_INTERACTION_NAME_CAPACITY);
    if (length >= nameOutSize) {
        length = nameOutSize - 1;
    }
    memcpy(nameOut, record->name, length);
    nameOut[length] = '\0';

    long long timestampMillis = record->timestampMillis;

    // Re-check: if the slot was recycled while we were copying, the name and the
    // timestamp may belong to different interactions. Drop the entry rather than
    // report a mismatched pair.
    if (atomic_load_explicit(&record->sequence, memory_order_acquire) != sequence) {
        return false;
    }

    if (timestampMillisOut != NULL) {
        *timestampMillisOut = timestampMillis;
    }
    return true;
}

void NRMA__clearInteractionHistory(void)
{
    // Async-signal-safe: retire every slot, then reset the counter. The backing
    // storage is permanent, so there is nothing to free and no pointer that
    // another thread could be left holding.
    for (uint32_t i = 0; i < NRMA_INTERACTION_HISTORY_CAPACITY; i++) {
        atomic_store_explicit(&__records[i].sequence, 0, memory_order_release);
    }
    atomic_store_explicit(&__insertCount, 0, memory_order_release);
}
