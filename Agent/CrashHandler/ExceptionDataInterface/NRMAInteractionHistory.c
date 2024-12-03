//
//  NRMAInteractionHistory.c
//  NewRelicAgent
//
//  Created by Bryce Buchanan on 5/19/14.
//  Copyright © 2023 New Relic. All rights reserved.
//

#include <stdio.h>
#include <stdlib.h>
#include <strings.h>
#include "NRMAInteractionHistory.h"


static NRMAInteractionHistoryNode* __list;

void NRMA__insertNode(NRMAInteractionHistoryNode* interaction);


void NRMA__AddInteraction(const char* interactionName, long long timestampMillis)
{

    if (interactionName == NULL || strlen(interactionName) == 0) {
        return;
    }

    NRMAInteractionHistoryNode* node  = (NRMAInteractionHistoryNode*)malloc(sizeof(NRMAInteractionHistoryNode));

    if (node == NULL) {
        return;
    }

    node->name = strdup(interactionName);
    if (node->name == NULL) {
        free(node);
        return;
    }
    node->timestampMillis = timestampMillis;
    node->next = NULL;

    NRMA__insertNode(node);
}

void NRMA__insertNode(NRMAInteractionHistoryNode* interaction)
{
    if (interaction == NULL) {
        return;
    }

    interaction->next = __list;
    __list = interaction;
}

void NRMA__setInteractionList(NRMAInteractionHistoryNode* list)
{
    __list = list;
}

NRMAInteractionHistoryNode* NRMA__getInteractionHistoryList(void)
{
    return __list;
}

void NRMA__deallocInteractionHistoryList(void)
{
    NRMAInteractionHistoryNode* current = __list;
    NRMAInteractionHistoryNode *next;

    while (current != NULL) {
        next = current->next;

        free((void*)current->name);
        free((void*)current);
        current = next;
    }

    __list = NULL;
}
