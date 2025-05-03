/**
 * @file ouiji_result.cl
 * @brief Definition of the OuijiResult structure returned from device to host
 */

#ifndef OUIJI_RESULT_H
#define OUIJI_RESULT_H

#include "lib/ouiji.cl" // Include the necessary headers for item and jokerdata types

typedef struct {
    int TotalScore;
    int ScoreWants[MAX_DESIRES_KERNEL];
    bool valid;
} OuijiResult;

#endif
