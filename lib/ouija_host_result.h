/**
 * @file ouija_host_result.h
 * @brief Definition of the OuijaHostResult structure matching the device-side OuijaResult
 */

#include <CL/cl.h>
#ifndef OUIJA_RESULT_H
#define OUIJA_RESULT_H

#ifndef MAX_DESIRES_HOST
#define MAX_DESIRES_HOST 16
#endif

// IMPORTANT: This struct must match the memory layout of OuijaResult in ouija_result.cl EXACTLY!
typedef struct {
    char seed[9];               // Matches the 8-byte seed + null terminator
    cl_ushort TotalScore;       // Matches `ushort` (16-bit unsigned integer)
    cl_uchar NegativeJokers;    // Matches `uchar` (8-bit unsigned integer)
    cl_uchar ScoreWants[MAX_DESIRES_HOST]; // Matches `uchar` array
} OuijaHostResult;

#endif
