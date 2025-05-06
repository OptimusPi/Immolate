/**
 * @file ouiji_result.cl
 * @brief Definition of the OuijiResult structure returned from device to host
 */

#include <CL/cl.h>
#ifndef OUIJI_RESULT_H
#define OUIJI_RESULT_H

#ifndef MAX_DESIRES_HOST
#define MAX_DESIRES_HOST 10
#endif

typedef struct {
    char seed[9];
    cl_int TotalScore;
    cl_int NegativeJokers;
    cl_int ScoreWants[MAX_DESIRES_HOST];
    cl_int valid;
} OuijiHostResult;

#endif
