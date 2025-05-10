#include "lib/ouija.cl"
#include "lib/ouija_config.cl" 
#include "lib/ouija_result.cl" 

OuijaResult ouija_filter(instance *inst, __global OuijaConfig *config);

__kernel void ouija_search(char8 starting_seed, 
                           long num_seeds,
                           __global OuijaConfig *config,
                           __global OuijaResult *results,
                           __global long *seed_offset) {
    
    size_t global_id = get_global_id(0);
    if (global_id >= num_seeds) {
        return;
    }
    
    size_t global_size = get_global_size(0);
    
    // Ensure the seed is correctly initialized and advanced
    seed _seed = s_new_c8(starting_seed);
    s_skip(&_seed, global_id + (*seed_offset));

    unsigned int result_idx = 0;

    // Ensure the first batch is processed and printed
    if (global_id == 0) {
        instance first_inst = i_new(_seed);
        results[0] = ouija_filter(&first_inst, config);
        s_skip(&_seed, global_size);
    }

    // Each thread processes its chunk of seeds
    for (long i = global_id; i < num_seeds; i += global_size) {
        // Compute unique result position
        unsigned int position = global_id + (result_idx * global_size);

        instance inst = i_new(_seed);
        results[position] = ouija_filter(&inst, config);

        result_idx++;

        // Skip for the next iteration
        s_skip(&_seed, global_size);
    }
}