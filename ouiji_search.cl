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
  
  
  
  printf("KERNEL: sizeof(OuijiConfig) on device: %d\n", (int)sizeof(OuijiConfig));
  printf("KERNEL: sizeof(Desire) on device: %d\n", (int)sizeof(Desire));

  
  char buf[9];
  for (int i = 0; i < 8; i++) buf[i] = starting_seed[i];
  buf[8] = '\0';
  printf("BEGIN ouiji_search with starting seed %s\n", buf);

  if (get_global_id(0) >= num_seeds) {
    printf("Kernel code exiting because global ID is greater than num_seeds\n");  
    return;
  }
  seed _seed = s_new_c8(starting_seed);
  text s_str1 = s_to_string(&_seed);
  printf("seed _seed = s_new_c8 returns a value of:  %s config cutoff: %d\n", s_str1.str, config->cutoff);

  long my_original_id = get_global_id(0);
  printf("ouiji_search with my_original_id = %lli\n", my_original_id);
  for (long i = get_global_id(0); i < num_seeds; i += get_global_size(0)) {
    printf("FOR LOOP...  ouiji_search with long i = %lli\n", i);
    s_skip(&_seed, i);
    s_str1 = s_to_string(&_seed);
    printf("FOR LOOP...  s_skip,  my_original_id = %lli, i = %lli, now seed is:  %s\n", my_original_id, i, s_str1.str);
    instance inst = i_new(_seed);
    OuijiResult result = ouiji_filter(&inst, config);
    printf("FOR LOOP...  my_original_id = %lli, i = %lli, ouiji_filter returns a result of:  %d\n", my_original_id, i, result.TotalScore);
    if (result.valid && result.TotalScore > 0 &&
        result.TotalScore >= config->cutoff) {
      // Print the seed and score
      text s_str = s_to_string(&_seed);
      int idx = atomic_inc(result_count);
      results[idx] = result;
      printf("%s (%d)\n", s_str.str, result.TotalScore);
      // Update the filter cutoff if necessary
#ifndef FIXED_FILTER_CUTOFF
      atomic_max(&config->cutoff, result.TotalScore);
#endif
    } else {
      printf("!!!! ELSE IN FOR LOOP...  my_original_id = %lli, i = %lli, ouiji_filter returns a result of:  TotalScore=%d Valid=%d config->cutoff:%d\n", my_original_id, i, result.TotalScore, result.valid, config->cutoff);
      if (result.valid)
        printf("...result.valid? YES\n");
      else
        printf("...result.valid? NO\n");
      if (result.TotalScore > 0)
        printf("...result.TotalScore > 0? YES\n");
      else
        printf("...result.TotalScore > 0? NO\n");
      if (result.TotalScore >= config->cutoff)
        printf("...result.TotalScore >= config->cutoff? YES\n");
      else
        printf("...result.TotalScore >= config->cutoff? NO\n");
      printf("...result.valid=%d, result.TotalScore=%d, config->cutoff=%d\n\n", result.valid, result.TotalScore, config->cutoff);
    }
  }
  printf("END  ouiji_search with my_original_id = %lli\n\n", my_original_id);
}