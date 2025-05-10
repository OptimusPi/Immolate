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

    // Each work-item will process a stride of seeds.
    // The loop iterates as long as the calculated seed index is within the number of seeds 
    // allocated to this particular kernel dispatch.
    for (long i = current_work_item_id; i < num_seeds_for_this_dispatch; i += total_work_items_in_dispatch) {
        // Calculate the actual seed to process for this iteration by this work-item:
        // 1. Start with the initial seed for the entire Ouija.exe run.
        // 2. Add the offset for the current batch/dispatch (passed by the host).
        // 3. Add the index 'i' which is unique for this work-item's current iteration within this dispatch.
        seed _seed = s_new_c8(starting_seed_char8); // Corrected: Use starting_seed_char8
        s_skip(&_seed, (*batch_seed_offset) + i);

        // The result for the seed processed at index 'i' (relative to the start of this dispatch)
        // should be placed at results[i].
        instance inst = i_new(_seed);
        results[i] = ouija_filter(&inst, config);
    }
}