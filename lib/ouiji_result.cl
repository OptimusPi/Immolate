/**
 * @file ouiji_result.cl
 * @brief Definition of the OuijiResult structure returned from device to host
 */

#ifndef OUIJI_RESULT_CL
#define OUIJI_RESULT_CL

#include "lib/ouiji.cl" // Include the necessary headers for item and jokerdata types

typedef struct {
    char seed[9]; // 8 bytes for the seed + 1 byte for null terminator
    int TotalScore;
    int NegativeJokers;
    int ScoreWants[MAX_DESIRES_KERNEL];
    int valid;
} OuijiResult;

#endif
