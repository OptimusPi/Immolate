/**
 * @file ouija_result.cl
 * @brief Definition of the OuijaResult structure returned from device to host
 */

#ifndef OUIJA_RESULT_CL
#define OUIJA_RESULT_CL

#include "lib/ouija.cl" // Include the necessary headers for item and jokerdata types

// IMPORTANT: This struct must match the memory layout of OuijaHostResult in ouija_host_result.h EXACTLY!
typedef struct {
    char seed[9]; // 8 bytes for the seed + 1 byte for null terminator
    ushort TotalScore; // Use 16-bit unsigned integer for scores (max value: 65,535)
    uchar NegativeJokers; // Use 8-bit unsigned integer for small values (max value: 255)
    uchar ScoreWants[MAX_DESIRES_KERNEL]; // Use 8-bit unsigned integers for wants
    // valid field removed - using TotalScore > 0 as validity indicator
} OuijaResult;

#endif
