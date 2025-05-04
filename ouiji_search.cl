#include "lib/ouiji.cl" // Includes all necessary headers
#include "lib/ouiji_config.cl" // Include the config header file
#include "lib/ouiji_result.cl" // Include the result header file

// Forward declaration of the filter function in template files
OuijiResult ouiji_filter(instance* inst, __global OuijiConfig* config);

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
        OuijiResult result = ouiji_filter(&inst, config);
        
        if (result.valid && result.TotalScore > 0) {
            text s_str = s_to_string(&_seed);
            printf("%s,%i,%i,%i,%i,%i,%i,%i,%i,%i,%i,%i\n",
                s_str.str,
                result.TotalScore,
                result.ScoreWants[0],
                result.ScoreWants[1],
                result.ScoreWants[2],
                result.ScoreWants[3],
                result.ScoreWants[4],
                result.ScoreWants[5],
                result.ScoreWants[6],
                result.ScoreWants[7],
                result.ScoreWants[8],
                result.ScoreWants[9]
            );
        }

        // Advance seed for the next iteration
        s_skip(&_seed, get_global_size(0));
    }
}