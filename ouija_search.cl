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
    // The batch_seed_offset is the offset for the current batch/dispatch, passed by the host.
    seed _seed = s_new_c8(starting_seed_char8);
    // Initialize the seed with the starting seed character8
    s_skip(&_seed, *batch_seed_offset);
    for (long i = current_work_item_id; i < num_seeds_for_this_dispatch; i += total_work_items_in_dispatch) {
        // For each work-item, we process a seed. The offset is added to the starting seed.
        s_skip(&_seed, (*batch_seed_offset) + i);

        // The result for the seed processed at index 'i' (relative to the start of this dispatch)
        // should be placed at results[i].
        instance inst = i_new(_seed);
        results[i] = ouija_filter(&inst, config);
    }
}