/**
 * @file ouija_host_result.h
 * @brief Definition of the OuijaHostResult structure matching the device-side OuijaResult
 */

#include <CL/cl.h>
#ifndef OUIJA_RESULT_H
#define OUIJA_RESULT_H

#ifndef MAX_DESIRES_HOST
#define MAX_DESIRES_HOST 32
#endif

typedef struct {
    cl_char seed[9];            // Bytes 0-8
    cl_ushort TotalScore;       // Bytes 9-10
    cl_uchar NegativeJokers;    // Byte 11
    cl_uchar NegativeJokersFromSkipTag; // Byte 12
    cl_uchar ScoreWants[MAX_DESIRES_HOST]; // Bytes 13 onwards
} OuijaHostResult;

#endif
