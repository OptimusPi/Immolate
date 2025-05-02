// Update kernel signature to accept the config struct from the host
__kernel void search(char8 starting_seed, long num_seeds, __global long* filter_cutoff, __global OuijiConfig* config_from_host) {
    seed _seed = s_new_c8(starting_seed);
    s_skip(&_seed, get_global_id(0));
    for (long i = get_global_id(0); i < num_seeds; i+=get_global_size(0)) {
        instance inst = i_new(_seed);
        // Ensure the correct function name 'ouiji_filter' is called with the config struct
        long score = ouiji_filter(&inst, config_from_host);
        if (score >= filter_cutoff[0]) {
            text s_str = s_to_string(&_seed);
            printf("%s (%li)\n", s_str.str, score);
            if (score > filter_cutoff[0]) {
                #ifndef FIXED_FILTER_CUTOFF
                    filter_cutoff[0] = score;
                    barrier(CLK_GLOBAL_MEM_FENCE);
                #endif
            }
        }
        s_skip(&_seed,get_global_size(0));
    }
}