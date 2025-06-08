/**
 * @file ouija_result.cl
 * @brief Definition of the OuijaResult structure returned from device to host
 */

#ifndef OUIJA_RESULT_CL
#define OUIJA_RESULT_CL

#include "lib/ouija.cl" // Include the necessary headers for item and jokerdata types

typedef struct {
    char seed[9];           // Bytes 0-8
    ushort TotalScore;      // Bytes 9-10
    uchar NegativeJokers;   // Byte 11
    uchar NegativeJokersFromSkipTag; // Byte 12
    uchar ScoreWants[MAX_DESIRES_KERNEL]; // Bytes 13 onwards
} OuijaResult;

#endif
