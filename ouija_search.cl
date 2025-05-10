#include "lib/ouija.cl"
#include "lib/ouija_config.cl" 
#include "lib/ouija_result.cl" 

OuijaResult ouija_filter(instance *inst, __global OuijaConfig *config);

__kernel void ouija_search(char8 starting_seed_char8, // Renamed to avoid conflict with seed type
                           long num_seeds_for_this_dispatch, // Total seeds this kernel dispatch should handle
                           __global OuijaConfig *config,
                           __global OuijaResult *results,
                           __global long *batch_seed_offset) { // Renamed for clarity
    
    size_t current_work_item_id = get_global_id(0); // ID of this specific work-item (0 to N-1)
    size_t total_work_items_in_dispatch = get_global_size(0); // Total work-items in this dispatch (N)
    
    seed _seed = s_new_c8(starting_seed_char8); // Initialize once from the global starting seed string

    // Calculate the absolute offset for the *first* seed this work-item should process
    long initial_offset_for_this_work_item = (*batch_seed_offset) + current_work_item_id;
    s_skip(&_seed, initial_offset_for_this_work_item); // Advance _seed to this work-item's starting point

    for (long i = current_work_item_id; i < num_seeds_for_this_dispatch; i += total_work_items_in_dispatch) {
        // _seed is now correctly positioned for the current 'i' by the initial skip
        // or by the s_skip at the end of the previous iteration.
        instance inst = i_new(_seed);
        results[i] = ouija_filter(&inst, config);

        // After processing, advance _seed by the stride to prepare for the next iteration (if any).
        // This skip will happen even after the last useful iteration for this work-item, which is harmless.
        s_skip(&_seed, total_work_items_in_dispatch);
    }
}