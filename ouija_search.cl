#include "lib/ouija.cl"
#include "lib/ouija_config.cl" 
#include "lib/ouija_result.cl" 

void ouija_filter(instance *inst, __constant OuijaConfig *config, __global OuijaResult *result);

__kernel void ouija_search(char8 starting_seed_char8, // Renamed to avoid conflict with seed type
                           long num_seeds_for_this_dispatch, // Total seeds this kernel dispatch should handle
                           __constant OuijaConfig *config,
                           __global OuijaResult *results,
                           __global long *batch_seed_offset) { // Renamed for clarity
    // Defensive batch size check - don't process unreasonably large batches
    if (num_seeds_for_this_dispatch > 1000000) { // 1 million seeds per batch limit
        // Process a reasonable number instead of failing completely
        num_seeds_for_this_dispatch = 1000000;
    }
    
    size_t current_global_id = get_global_id(0); // Original OpenCL type: size_t
    size_t total_global_size = get_global_size(0); // Original OpenCL type: size_t
    
    seed _seed = s_new_c8(starting_seed_char8); // Initialize once from the global starting seed string
    text seedPrint = s_to_string(&_seed); // Convert the seed to a string for debugging
    //printf("[KERNEL-Ouija_Search] Starting seed: %s\n", seedPrint.str); // Debugging output
    // Consistently use %lu for size_t, casting to unsigned long for printf portability
    //printf("[KERNEL-Ouija_Search] Current work-item ID (raw size_t): %lu\n", (unsigned long)current_global_id); 

    // For the main loop logic, which depends on num_seeds_for_this_dispatch (long),
    // we'll use 'long' for the loop variable and related calculations.
    long loop_start_index = (long)current_global_id;
    long loop_stride = (long)total_global_size;

    // Calculate the absolute offset for the *first* seed this work-item should process
    // (*batch_seed_offset) is long, loop_start_index is now long.
    long initial_offset_for_this_work_item = (*batch_seed_offset) + loop_start_index;
    s_skip(&_seed, initial_offset_for_this_work_item); // s_skip expects int64_t (long in OpenCL)

    // Loop variable 'i' is long, matching num_seeds_for_this_dispatch.
    // loop_start_index and loop_stride are also long.
    for (long i = loop_start_index; i < num_seeds_for_this_dispatch; i += loop_stride) {
        // i and loop_start_index are long, so %li is appropriate.
        //printf("[KERNEL-Ouija_Search] Processing seed %li for work-item %li\n", i, loop_start_index); 
          instance inst = i_new(_seed);
        
        // Ensure memory is synchronized before processing this batch item
        barrier(CLK_LOCAL_MEM_FENCE);
        
        // results is indexed by 'i' (long).
        ouija_filter(&inst, config, &results[i]); // Process the instance with the current configuration
        
        // Ensure memory writes from the filter are complete before moving to the next seed
        barrier(CLK_GLOBAL_MEM_FENCE);
        mem_fence(CLK_GLOBAL_MEM_FENCE);
        
        // After processing, advance _seed by the stride to prepare for the next iteration (if any).
        // loop_stride is long, compatible with s_skip's int64_t.
        s_skip(&_seed, loop_stride);
    }
}