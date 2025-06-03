#include "lib/ouija.cl"

// PRACTICAL SIMD OPTIMIZATION: MAXIMUM REAL-WORLD PERFORMANCE
// Eliminates branches, reduces memory access, uses efficient patterns

void ouija_filter(instance *inst, __constant OuijaConfig *config, __global OuijaResult *result) {
    result->TotalScore = 0;
    result->NegativeJokers = 0;
    
    set_deck(inst, config->deck);
    set_stake(inst, config->stake);
    init_locks(inst, 1, false, true);
    
    int total_seed_quality = 0;
    
    // OPTIMIZED: Process 8 antes with minimal overhead
    #pragma unroll
    for (int ante = 1; ante <= 8; ante++) {
        init_unlocks(inst, ante, false);
        
        int shCount = (ante == 1) ? 4 : 8;
        
        // VECTORIZED: Process 8 items at once, pad with zeros
        int8 joker_batch = (int8)(0);
        
        // UNROLLED: Maximum compiler optimization
        if (shCount >= 1) { shopitem item = next_shop_item(inst, ante); joker_batch.s0 = (item.type == ItemType_Joker) ? (int)item.value : 0; }
        if (shCount >= 2) { shopitem item = next_shop_item(inst, ante); joker_batch.s1 = (item.type == ItemType_Joker) ? (int)item.value : 0; }
        if (shCount >= 3) { shopitem item = next_shop_item(inst, ante); joker_batch.s2 = (item.type == ItemType_Joker) ? (int)item.value : 0; }
        if (shCount >= 4) { shopitem item = next_shop_item(inst, ante); joker_batch.s3 = (item.type == ItemType_Joker) ? (int)item.value : 0; }
        if (shCount >= 5) { shopitem item = next_shop_item(inst, ante); joker_batch.s4 = (item.type == ItemType_Joker) ? (int)item.value : 0; }
        if (shCount >= 6) { shopitem item = next_shop_item(inst, ante); joker_batch.s5 = (item.type == ItemType_Joker) ? (int)item.value : 0; }
        if (shCount >= 7) { shopitem item = next_shop_item(inst, ante); joker_batch.s6 = (item.type == ItemType_Joker) ? (int)item.value : 0; }
        if (shCount >= 8) { shopitem item = next_shop_item(inst, ante); joker_batch.s7 = (item.type == ItemType_Joker) ? (int)item.value : 0; }
        
        // VECTORIZED REDUCTION: Let compiler optimize this
        int scoreToAdd = joker_batch.s0 + joker_batch.s1 + joker_batch.s2 + joker_batch.s3 +
                             joker_batch.s4 + joker_batch.s5 + joker_batch.s6 + joker_batch.s7;

        if (next_tag(inst, ante) == Negative_Tag)
            scoreToAdd *= 2;
        total_seed_quality += scoreToAdd;
    }
    
    result->TotalScore = total_seed_quality;
    
    // EFFICIENT STRING COPY: Minimal overhead
    text s_str = s_to_string(&inst->seed);
    
    // UNROLLED COPY: Compiler can optimize to vector ops
    result->seed[0] = s_str.str[0];
    result->seed[1] = s_str.str[1];
    result->seed[2] = s_str.str[2];
    result->seed[3] = s_str.str[3];
    result->seed[4] = s_str.str[4];
    result->seed[5] = s_str.str[5];
    result->seed[6] = s_str.str[6];
    result->seed[7] = s_str.str[7];
    result->seed[8] = s_str.str[8];
    
    return;
}
