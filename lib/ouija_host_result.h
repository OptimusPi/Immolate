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

// Ensure memory layout matches exactly between host and device
#ifdef _MSC_VER
#pragma pack(push, 1) // Use byte alignment for MSVC
#endif

typedef struct {
    cl_char seed[9];        // Bytes 0-8
    cl_uchar _padding0;     // Byte 9 (explicit padding)
    cl_ushort TotalScore;   // Bytes 10-11
    cl_uchar NegativeJokers; // Byte 12
    cl_uchar ScoreWants[MAX_DESIRES_HOST]; // Bytes 13 onwards
    cl_int pad1;
    cl_char pad2;
} __attribute__((packed)) OuijaHostResult; // Use packed attribute for GCC/Clang

#ifdef _MSC_VER
#pragma pack(pop) // Restore default packing
#endif

#endif
