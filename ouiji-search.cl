#include "lib/ouiji.cl" // Includes all necessary headers
#include "lib/ouiji_config.h" // Include the config header file

// Define the result structure
typedef struct {
    seed _seed;
    long score;
    unsigned int wants_mask; // Bitmask for up to 32 wants
} ResultInfo;

// Define buffer size limit
#define MAX_RESULTS_BUFFER 10000

// Forward declaration of the filter function in template files
long ouiji_filter(instance* inst, __global OuijiConfig* config);

__kernel void search(
    char8 starting_seed,
    long num_seeds,
    __global OuijiConfig* config,  // Changed the order - moved config up to be the 3rd param
    __global ResultInfo* results_buffer,
    __global volatile uint* result_count // Changed to match what atom_inc expects
) {
    seed _seed = s_new_c8(starting_seed);
    s_skip(&_seed, get_global_id(0));

    for (long i = get_global_id(0); i < num_seeds; i += get_global_size(0)) {
        instance inst = i_new(_seed);
        
        // Call ouiji_filter with the correct parameter types
        long score = ouiji_filter(&inst, config);
        unsigned int wants_mask = 0; // Default for now
        
        if (score >= config->cutoff) { // Use the cutoff from config
            text s_str = s_to_string(&_seed);
            printf("%s (%li)\n", s_str.str, score);
            
            // Store result in buffer if within limit
            unsigned int idx = atom_inc(result_count);
            if (idx < MAX_RESULTS_BUFFER) {
                ResultInfo result;
                result._seed = _seed;
                result.score = score;
                result.wants_mask = wants_mask;
                results_buffer[idx] = result;
            }
        }

        // Advance seed for the next iteration
        s_skip(&_seed, get_global_size(0));
    }
}