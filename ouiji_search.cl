#include "lib/ouiji.cl" // Includes all necessary headers
#include "lib/ouiji_config.cl" // Include the config header file

// Forward declaration of the filter function in template files
long long ouiji_filter(instance* inst, __global OuijiConfig* config);

__kernel void ouiji_search(
    char8 starting_seed,
    long num_seeds,
    __global OuijiConfig* config
) {
    seed _seed = s_new_c8(starting_seed);
    s_skip(&_seed, get_global_id(0));

    for (long long i = get_global_id(0); i < num_seeds; i += get_global_size(0)) {
        instance inst = i_new(_seed);
        
        // Call ouiji_filter with the correct parameter types
        long long score = ouiji_filter(&inst, config);
        
        if (score >= config->cutoff) { // Use the cutoff from config
            text s_str = s_to_string(&_seed);
            printf("%s (%li)\n", s_str.str, score);
        }

        // Advance seed for the next iteration
        s_skip(&_seed, get_global_size(0));
    }
}