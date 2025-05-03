/**
 * @file ouiji_config.h
 * @brief Definition of the OuijiConfig structure shared between host and device
 */

#ifndef OUIJI_CONFIG_H
#define OUIJI_CONFIG_H

#ifdef __OPENCL_VERSION__
    // For OpenCL device code
    #include "items.cl"
    #define MAX_DESIRES_KERNEL 10
    typedef struct {
        item Needs[MAX_DESIRES_KERNEL];
        item Wants[MAX_DESIRES_KERNEL];
        int numNeeds;
        int numWants;
        int needByAnte;
        int wantByAnte;
        int needByAntePerkeo; // Example specific field
        long cutoff; // Include cutoff here
    } OuijiConfig;
#else
    // For host C code
    #include "items.h"
    #define MAX_DESIRES_KERNEL 10
    typedef struct {
        int Needs[MAX_DESIRES_KERNEL];
        int Wants[MAX_DESIRES_KERNEL];
        int numNeeds;
        int numWants;
        int needByAnte;
        int wantByAnte;
        int needByAntePerkeo;
        long cutoff;
    } OuijiConfig;
#endif

#endif /* OUIJI_CONFIG_H */
