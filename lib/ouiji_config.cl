/**
 * @file ouiji_config.cl
 * @brief Definition of the OuijiConfig structure shared between host and device
 */

#ifndef OUIJI_CONFIG_H
#define OUIJI_CONFIG_H

// Maximum number of results that can be stored in the result buffer
#define MAX_RESULTS 1024

#include "lib/ouiji.cl" // Include the necessary headers for item and jokerdata types

// Enhanced desire structure with per-item ante requirement
typedef struct {
    item value;               // Item or Joker ID
    item jokeredition;           // Edition of the joker, or RETRY if not a joker
    int desireByAnte;         // Ante by which this item should be found
} Desire;

typedef struct {
    int numNeeds;                      // Number of Needs
    int numWants;                      // Number of Wants
    Desire Needs[MAX_DESIRES_KERNEL];  // Array of Needs
    Desire Wants[MAX_DESIRES_KERNEL];  // Array of Wants
    int maxSearchAnte;                 // Maximum Ante to search through
    int deck;                          // Deck to use
    int stake;                         // Stake to use
} OuijiConfig;

#endif
