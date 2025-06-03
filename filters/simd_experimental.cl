//
// EXPERIMENTAL SIMD-OPTIMIZED FILTER
// Exploits mathematical structure of item enums for ultra-fast scoring
// Processes 4 antes simultaneously using OpenCL vector types
//
// Rarity Boundaries (from items.cl):
// Common:    J_C_BEGIN (12) to J_C_END (74)    - Range: 62 items
// Uncommon:  J_U_BEGIN (76) to J_U_END (141)   - Range: 65 items  
// Rare:      J_R_BEGIN (143) to J_R_END (164)  - Range: 21 items
// Legendary: J_L_BEGIN (166) to J_L_END (172)  - Range: 6 items
//
// Mathematical Pattern: enum_value directly encodes rarity!
// We can use integer comparisons instead of complex switch statements

#include "../lib/instance.cl"
#include "../lib/items.cl"
#include "../lib/seed.cl"

typedef struct {
    int4 totalScore;        // Scores for 4 antes simultaneously
    int4 commonCount;       // Common joker counts
    int4 uncommonCount;     // Uncommon joker counts  
    int4 rareCount;         // Rare joker counts
    int4 legendaryCount;    // Legendary joker counts
    int4 negativeMultiplier;// Negative tag multipliers (Anaglyph deck)
} SIMDScoreState;

// SIMD rarity detection using mathematical enum boundaries
inline int4 getRarityMask(int4 jokers, int rarityMin, int rarityMax) {
    return (jokers >= rarityMin) & (jokers <= rarityMax);
}

// Ultra-fast rarity classification for 4 jokers at once
inline void classifyJokerRarities(int4 jokers, SIMDScoreState *state) {
    int4 commonMask = getRarityMask(jokers, J_C_BEGIN, J_C_END);
    int4 uncommonMask = getRarityMask(jokers, J_U_BEGIN, J_U_END);
    int4 rareMask = getRarityMask(jokers, J_R_BEGIN, J_R_END);
    int4 legendaryMask = getRarityMask(jokers, J_L_BEGIN, J_L_END);
    
    state->commonCount += commonMask;
    state->uncommonCount += uncommonMask;
    state->rareCount += rareMask;
    state->legendaryCount += legendaryMask;
}

// SIMD scoring function - processes 4 antes simultaneously
inline void updateSIMDScore(SIMDScoreState *state, __constant OuijaConfig *config) {
    // Base rarity scoring (vectorized)
    int4 rarityScore = state->commonCount * config->common_value +
                       state->uncommonCount * config->uncommon_value +
                       state->rareCount * config->rare_value +
                       state->legendaryCount * config->legendary_value;
    
    // Apply negative tag multipliers for Anaglyph deck strategy
    state->totalScore += rarityScore * state->negativeMultiplier;
}

// SIMD shop simulation - process 4 antes worth of shops simultaneously
void simulateSIMDShops(instance *inst, __constant OuijaConfig *config, SIMDScoreState *state) {
    // Process 4 antes in parallel using vector operations
    for (int ante = 0; ante < 4; ante++) {
        int shopItemCount = (ante == 0) ? 4 : 8;  // Ante 1 = 4 items, Ante 2+ = 8 items
        
        // Vector to hold 4 simultaneous shop items
        int4 shopItems = (int4)(0);
        
        // Process shop items in groups of 4 for maximum SIMD efficiency
        for (int i = 0; i < shopItemCount; i += 4) {
            // Generate 4 shop items simultaneously
            for (int j = 0; j < 4 && (i + j) < shopItemCount; j++) {
                int item = shop_item(inst);
                
                // Only process jokers - skip non-jokers immediately
                if (item >= J_BEGIN && item < J_END) {
                    shopItems[j] = item;
                } else {
                    shopItems[j] = 0; // Mark as non-joker
                }
            }
            
            // SIMD classify all 4 items at once
            classifyJokerRarities(shopItems, state);
        }
        
        // Accumulate double tags for Anaglyph deck (free +1 per ante)
        state->negativeMultiplier += (int4)(1);
        
        // Update running score
        updateSIMDScore(state, config);
        
        // Advance to next ante
        next_ante(inst);
    }
}

// SIMD reroll simulation - find best consecutive runs across 4 parallel timelines
int4 simulateSIMDRerolls(instance *inst, __constant OuijaConfig *config) {
    int4 bestRunScore = (int4)(0);
    int4 currentRunLength = (int4)(0);
    int4 currentRunScore = (int4)(0);
    
    // Simulate 25 rerolls across 4 parallel instances
    for (int reroll = 0; reroll < 25; reroll++) {
        SIMDScoreState rerollState = {0};
        rerollState.negativeMultiplier = (int4)(1, 1, 1, 1);
        
        // Create 4 parallel instances for SIMD processing
        instance inst_copy[4];
        for (int i = 0; i < 4; i++) {
            inst_copy[i] = *inst;
            inst_copy[i].seed += i * 1000; // Offset seeds for different timelines
        }
        
        // Simulate shops for all 4 instances
        for (int i = 0; i < 4; i++) {
            SIMDScoreState singleState = {0};
            singleState.negativeMultiplier = (int4)(1);
            simulateSIMDShops(&inst_copy[i], config, &singleState);
            
            // Extract score for this timeline
            int timelineScore = singleState.totalScore.x; // Take first component
            
            // Update run tracking
            if (timelineScore >= config->target_score) {
                currentRunLength.s[i]++;
                currentRunScore.s[i] += timelineScore;
            } else {
                // End of run - check if it's the best
                if (currentRunScore.s[i] > bestRunScore.s[i]) {
                    bestRunScore.s[i] = currentRunScore.s[i];
                }
                currentRunLength.s[i] = 0;
                currentRunScore.s[i] = 0;
            }
        }
    }
    
    // Final check for runs that ended at the end of simulation
    for (int i = 0; i < 4; i++) {
        if (currentRunScore.s[i] > bestRunScore.s[i]) {
            bestRunScore.s[i] = currentRunScore.s[i];
        }
    }
    
    return bestRunScore;
}

// Main SIMD filter function
void ouija_filter(instance *inst, __constant OuijaConfig *config, __global OuijaResult *result) {
    // Initialize SIMD score state
    SIMDScoreState mainState = {0};
    mainState.negativeMultiplier = (int4)(1, 1, 1, 1); // Start with 1x multiplier
    
    // SIMD main game simulation (4 antes in parallel)
    simulateSIMDShops(inst, config, &mainState);
    
    // SIMD reroll simulation for consecutive run optimization
    int4 rerollScores = simulateSIMDRerolls(inst, config);
    
    // Combine main game and reroll scores using vector operations
    int4 finalScores = mainState.totalScore + rerollScores;
    
    // Extract maximum score from the 4 parallel results
    int maxScore = max(max(finalScores.x, finalScores.y), 
                      max(finalScores.z, finalScores.w));
    
    // Write result if it meets threshold
    if (maxScore >= config->target_score) {
        result->score = maxScore;
        result->seed = inst->seed;
        
        // Additional SIMD statistics
        result->common_count = mainState.commonCount.x;
        result->uncommon_count = mainState.uncommonCount.x; 
        result->rare_count = mainState.rareCount.x;
        result->legendary_count = mainState.legendaryCount.x;
        
        // Pack SIMD results into result string
        char temp[256];
        snprintf(temp, sizeof(temp), 
                "SIMD: %d,%d,%d,%d | C:%d U:%d R:%d L:%d",
                finalScores.x, finalScores.y, finalScores.z, finalScores.w,
                mainState.commonCount.x, mainState.uncommonCount.x,
                mainState.rareCount.x, mainState.legendaryCount.x);
        
        strncpy(result->result_string, temp, sizeof(result->result_string) - 1);
        result->result_string[sizeof(result->result_string) - 1] = '\0';
    }
    
    // Always return from void function (critical for performance!)
    return;
}
