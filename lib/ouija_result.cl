/**
 * @file ouija_result.cl
 * @brief Definition of the OuijaResult structure returned from device to host
 */

#ifndef OUIJA_RESULT_CL
#define OUIJA_RESULT_CL

#include "lib/ouija.cl" // Include the necessary headers for item and jokerdata types

/* 
 * Define the structure with explicit padding and memory layout to match host side.
 * The __attribute__ directive ensures correct memory alignment across devices.
 */
typedef struct __attribute__((packed)) {
    char seed[9];           // Bytes 0-8
    uchar _padding0;        // Byte 9 (explicit padding)
    ushort TotalScore;      // Bytes 10-11
    uchar NegativeJokers;   // Byte 12
    uchar ScoreWants[MAX_DESIRES_KERNEL]; // Bytes 13 onwards
    int pad1;
    char pad2;
} OuijaResult;

#endif
