/**
 * @file ouiji_config.cl
 * @brief Definition of the OuijiConfig structure shared between host and device
 */

#ifndef OUIJI_CONFIG_H
#define OUIJI_CONFIG_H

#include "lib/ouiji.cl" // Include the necessary headers for item and jokerdata types

typedef enum {
    DesireType_Joker = 0,
    DesireType_Value = 1,
} desiretype;

// Object that contains a joker and its rarity.
typedef struct JokerDesireData {
    item joker;
    item edition;
} jokerdesiredata;

// Enhanced desire structure with per-item ante requirement
typedef struct {
    desiretype type;
    item value;
    jokerdesiredata joker;
    int desireByAnte;  // Individual ante target for this specific item
} desire;

typedef struct {
    int numNeeds;
    int numWants;
    desire Needs[MAX_DESIRES_KERNEL];
    desire Wants[MAX_DESIRES_KERNEL];
    int maxSearchAnte;  // Maximum ante to search through (for optimization)
    item deck;
    item stake;
    long cutoff;

} OuijiConfig;
#endif
