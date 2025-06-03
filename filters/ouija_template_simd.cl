#include "lib/ouija.cl"

// EXPERIMENTAL SIMD FILTER: MATHEMATICAL SEED QUALITY HASH
// This filter creates a "scoreable hash" for Balatro seeds using pure integer arithmetic
// Potentially GROUNDBREAKING for the Balatro community!

// Joker rarity boundaries (based on item enum structure)
#define J_COMMON_START    J_C_BEGIN
#define J_UNCOMMON_START  J_U_BEGIN  
#define J_RARE_START      J_R_BEGIN
#define J_LEGENDARY_START J_L_BEGIN

// PURE MATHEMATICAL HASH: Just use raw joker enum values!
// Higher enum values = rarer jokers = better seeds
// No artificial weights needed - the enum IS the weight!

void ouija_filter(instance *inst, __constant OuijaConfig *config, __global OuijaResult *result) {
    result->TotalScore = 0;
    result->NegativeJokers = 0;
    set_deck(inst, config->deck);
    set_stake(inst, config->stake);
    init_locks(inst, 1, false, true);
    
    int maxSearchAnte = 8; // SIMD works best with 8 antes
    int total_seed_quality = 0;
    int ante_quality_scores[8] = {0}; // Track per-ante for analysis
    
    // EXPERIMENTAL: Process 8 antes for maximum SIMD efficiency
    for (int ante = 1; ante <= maxSearchAnte; ante++) {
        init_unlocks(inst, ante, false);
        // CORE SIMD OPTIMIZATION: Score shop items with pure integer math
        int shop_quality = 0;        
        int shCount = (ante == 1) ? 4 : 8;

        if (next_tag(inst, ante) != Negative_Tag) {
            // Handle retry tag - skip this ante
            continue;
        }
        
        // Process shop items in SIMD-friendly batches of 8
        for (int sh = 0; sh < shCount; sh += 8) {
            int8 joker_batch = (int8)(0);            // Load 8 shop items at once (or pad with zeros)
            for (int i = 0; i < 8 && (sh + i) < shCount; i++) {
                shopitem item = next_shop_item(inst, ante);
                if (item.type == ItemType_Joker) {
                    // Direct array-style access - much cleaner!
                    ((int*)&joker_batch)[i] = (int)item.value;
                    
                    // Count negative jokers
                    if (item.joker.edition == Negative) {
                        result->NegativeJokers++;
                    }
                }
            // SIMD magic: Score all 8 items in parallel!
            shop_quality += joker_batch.s0 + joker_batch.s1 + joker_batch.s2 + joker_batch.s3 +
                           joker_batch.s4 + joker_batch.s5 + joker_batch.s6 + joker_batch.s7;
            }
            
            ante_quality_scores[ante - 1] = shop_quality;
            total_seed_quality += shop_quality;
        }
    }
    
    // PURE SPEED: Just add everything together - no fancy math!
    result->TotalScore = total_seed_quality;
    // Convert seed to string
    text s_str = s_to_string(&inst->seed);
    
    // Copy seed string efficiently 
    #pragma unroll
    for (int i = 0; i < 9; i++) {
        result->seed[i] = s_str.str[i];
    }
    
    return;
}
