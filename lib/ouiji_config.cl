/**
 * @file ouiji_config.cl
 * @brief Definition of the OuijiConfig structure shared between host and device
 */

#ifndef OUIJI_CONFIG_H
#define OUIJI_CONFIG_H

// Maximum number of results that can be stored in the result buffer
#define MAX_RESULTS 1024

#include "lib/ouiji.cl" // Include the necessary headers for item and jokerdata types

typedef enum {
    DesireType_Joker = 0,
    DesireType_Value = 1,
} desiretype;

// Enhanced desire structure with per-item ante requirement
typedef struct {
    desiretype type;          // 0 = DesireType_Joker, 1 = DesireType_Value
    item value;               // Item or Joker ID
    jokerdata joker;          // Joker and Edition details
    int desireByAnte;         // Ante by which this item should be found
} Desire;

typedef struct {
    int numNeeds;                      // Number of Needs
    int numWants;                      // Number of Wants
    Desire Needs[MAX_DESIRES_KERNEL];  // Array of Needs
    Desire Wants[MAX_DESIRES_KERNEL];  // Array of Wants
    int maxSearchAnte;                 // Maximum Ante to search through
    item deck;                         // Deck to use
    item stake;                        // Stake to use
    long cutoff;                       // Minimum score to report
} OuijiConfig;

#endif
