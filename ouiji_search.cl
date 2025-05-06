// Include a define to check for fixed cutoff
// #define FIXED_FILTER_CUTOFF

#include "lib/ouiji.cl"        // Includes all necessary headers
#include "lib/ouiji_config.cl" // Include the config header file
#include "lib/ouiji_result.cl" // Include the result header file

// Forward declaration of the filter function in template files
OuijiResult ouiji_filter(instance *inst, __global OuijiConfig *config);

__kernel void ouiji_search(char8 starting_seed, long num_seeds,
                           __global OuijiConfig *config,
                           __global OuijiResult *results,
                           __global int *result_count) {


  
  char buf[9];
  for (int i = 0; i < 8; i++) buf[i] = starting_seed[i];
  buf[8] = '\0';

  if (get_global_id(0) >= num_seeds) {
    return;
  }
  seed _seed = s_new_c8(starting_seed);
  text s_str1 = s_to_string(&_seed);

  long my_original_id = get_global_id(0);
  for (long i = get_global_id(0); i < num_seeds; i += get_global_size(0)) {
    s_skip(&_seed, i);
    s_str1 = s_to_string(&_seed);
    instance inst = i_new(_seed);
    OuijiResult result = ouiji_filter(&inst, config);
    if (result.valid && result.TotalScore > 0 &&
        result.TotalScore >= config->cutoff) {
      // Print the seed and score
      result.seed[0] = s_str1.str[0];
      result.seed[1] = s_str1.str[1];
      result.seed[2] = s_str1.str[2];
      result.seed[3] = s_str1.str[3];
      result.seed[4] = s_str1.str[4];
      result.seed[5] = s_str1.str[5];
      result.seed[6] = s_str1.str[6];
      result.seed[7] = s_str1.str[7];
      result.seed[8] = '\0'; // Null-terminate the string
      int idx = atomic_inc(result_count);
      results[idx] = result;
      // Update the filter cutoff if necessary
#ifndef FIXED_FILTER_CUTOFF
      atomic_max(&config->cutoff, result.TotalScore);
#endif
    }
  }
}