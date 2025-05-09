#include "lib/ouija.cl"
#include "lib/ouija_config.cl" 
#include "lib/ouija_result.cl" 

__kernel void ouija_search(char8 starting_seed, long num_seeds,
                           __global OuijaConfig *config,
                           __global int *dynamic_cutoff,
                           __global OuijaResult *results,
                           __global long *seed_offset) {
    
    size_t global_id = get_global_id(0);
    size_t global_size = get_global_size(0);
        long batch_offset = *seed_offset;
    unsigned int result_idx = 0;
    
    // Each thread processes its chunk of seeds
    for (long i = global_id; i < num_seeds; i += global_size) {
        // Generate seed
        seed _seed = s_new_c8(starting_seed);
        s_skip(&_seed, batch_offset + i);
        
        // Compute position using stride pattern to avoid atomic operations
        // Each thread writes to its own segment of the buffer
        unsigned int position = global_id + (result_idx * global_size);
        
        // Get seed as string and store it
        text s_str = s_to_string(&_seed);
        for (int j = 0; j < 8 && s_str.str[j] != '\0'; j++) {
            results[position].seed[j] = s_str.str[j];
        }
        results[position].seed[8] = '\0';
        
        // Fill with dummy values - the real output is through s_print_fake
        results[position].TotalScore = 4;
        results[position].NegativeJokers = 1;
        for (int w = 0; w < MAX_DESIRES_KERNEL; w++) {
            results[position].ScoreWants[w] = 0;
        }            // Just to match the printed fake data
        results[position].ScoreWants[MAX_DESIRES_KERNEL-1] = 2;
        
        // Increment the local result counter
        result_idx++;
    }
}