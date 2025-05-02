#include "lib/immolate.cl"

// Structure to track our complex game state
typedef struct {
    bool hasNegativeLuckyCat;
    bool hasMadness;
    bool hasEternalMissing;
    bool hasTheArchitect;
    bool hasMagicianBefore3;
    bool hasBlueprintOrBrainstorm;
    bool hasPolyOopsAll;
    bool hasNegativeTarots;
    bool hasGoldenVoucher;
    int tarotCount;
    int anteOfTelescopeVoucher;
    int negativeTagsConsecutive;
    int spectralNegLegendaries;
    instance* inst;
} cascading_state;

// Examine and score a joker based on our complex criteria
int analyze_joker(jokerdata joker, int ante, cascading_state* state) {
    int score = 0;
    
    // Check for our primary target combo pieces
    if (joker.joker == Lucky_Cat && joker.edition == Negative) {
        state->hasNegativeLuckyCat = true;
        score += 100 * (7 - ante); // Higher score for finding earlier
    }
    
    if (joker.joker == Madness) {
        if (joker.stickers.eternal) {
            score += 50;
            state->hasMadness = true;
        } else {
            score += 10;
        }
    }
    
    if (joker.joker == Missing_Joker && joker.stickers.eternal) {
        state->hasEternalMissing = true;
        score += 75;
    }
    
    if (joker.joker == The_Architect && ante <= 2) {
        state->hasTheArchitect = true;
        score += 60;
    }
    
    if ((joker.joker == Blueprint || joker.joker == Brainstorm) && ante <= 3) {
        state->hasBlueprintOrBrainstorm = true;
        score += 40;
    }
    
    if (joker.joker == Oops_All_6s && joker.edition == Polychrome) {
        state->hasPolyOopsAll = true;
        score += 65;
    }
    
    // Special scoring for tarot-based synergies
    if (joker.joker >= Fool && joker.joker <= World) {
        state->tarotCount++;
        if (joker.edition == Negative) {
            state->hasNegativeTarots = true;
            state->spectralNegLegendaries++;
            score += 35;
        }
    }
    
    // Slightly boost any negative joker
    if (joker.edition == Negative) {
        score += 5;
    }
    
    // General score for polychromes
    if (joker.edition == Polychrome) {
        score += 8;
    }
    
    return score;
}

// Check shop items with our advanced criteria
int check_shop(int ante, int maxItems, cascading_state* state) {
    int score = 0;
    
    for (int i = 0; i < maxItems; i++) {
        shopitem item = next_shop_item(state->inst, ante);
        
        // Check for jokers
        if (item.type == ItemType_Joker) {
            score += analyze_joker(item.joker, ante, state);
        }
        // Check for key spectral cards
        else if (item.type == ItemType_Spectral) {
            if (item.value == The_Magician && ante <= 3) {
                state->hasMagicianBefore3 = true;
                score += 45;
            }
            else if (item.value == Golden_Voucher) {
                state->hasGoldenVoucher = true;
                score += 30;
            }
            else if (item.value == The_Soul) {
                // Check what the Soul will give
                jokerdata soulJoker = next_joker_with_info(state->inst, S_Soul, ante);
                if (soulJoker.joker != RETRY) {
                    score += analyze_joker(soulJoker, ante, state);
                }
            }
        }
    }
    
    return score;
}

// Check vouchers for specific patterns
void check_vouchers(int ante, cascading_state* state) {
    voucher v = next_voucher(state->inst, ante);
    if (v == Telescope) {
        state->anteOfTelescopeVoucher = ante;
        activate_voucher(state->inst, Telescope);
    }
    else if (v == Observatory && state->anteOfTelescopeVoucher > 0) {
        // Only count Observatory if we already have Telescope
        activate_voucher(state->inst, Observatory);
    }
}

// Check for consecutive Negative tags
int check_tags(int ante, cascading_state* state) {
    int score = 0;
    int negativeTagsThisAnte = 0;
    
    // Check first blind
    tag t1 = next_tag(state->inst, ante);
    if (t1 == Negative_Tag) {
        negativeTagsThisAnte++;
        score += 20;
    }
    
    // Check second blind
    tag t2 = next_tag(state->inst, ante);
    if (t2 == Negative_Tag) {
        negativeTagsThisAnte++;
        score += 20;
    }
    
    // Burn boss tag call
    next_orbital_tag(state->inst);
    
    // Update consecutive tags counter
    if (negativeTagsThisAnte == 2) {
        state->negativeTagsConsecutive++;
        score += 25 * state->negativeTagsConsecutive; // Progressive bonus
    } else {
        state->negativeTagsConsecutive = 0;
    }
    
    return score;
}

long filter(instance* inst) {
    // Set up basic game parameters
    set_deck(inst, Ghost_Deck);
    set_stake(inst, Black_Stake);
    init_locks(inst, 1, false, false);
    
    // Initialize our cascade state tracking
    cascading_state state = {false};
    state.inst = inst;
    state.anteOfTelescopeVoucher = 0;
    
    int totalScore = 0;
    
    // Search through first 5 antes for our complex pattern
    for (int ante = 1; ante <= 5; ante++) {
        init_unlocks(inst, ante, false);
        
        // Check for tag patterns
        totalScore += check_tags(ante, &state);
        
        // Check shop items (more thorough in early antes)
        int itemsToCheck = (ante <= 2) ? 8 : 6;
        totalScore += check_shop(ante, itemsToCheck, &state);
        
        // Look for telescope/observatory
        check_vouchers(ante, &state);
        
        // Early termination conditions
        if (ante >= 3) {
            // By ante 3 we need at least one of our core pieces
            if (!state.hasNegativeLuckyCat && 
                !state.hasMadness && 
                !state.hasEternalMissing &&
                !state.hasTheArchitect) {
                return 0;
            }
            
            // Need Lucky Cat enabler
            if (state.hasNegativeLuckyCat && !state.hasMagicianBefore3) {
                return 0;
            }
        }
        
        // By ante 5 we need more pieces for our strategy
        if (ante == 5) {
            // Count how many key components we have
            int keyComponents = 0;
            if (state.hasNegativeLuckyCat) keyComponents++;
            if (state.hasMadness) keyComponents++;
            if (state.hasEternalMissing) keyComponents++;
            if (state.hasTheArchitect) keyComponents++;
            if (state.hasBlueprintOrBrainstorm) keyComponents++;
            if (state.hasPolyOopsAll) keyComponents++;
            if (state.hasNegativeTarots) keyComponents++;
            if (state.anteOfTelescopeVoucher > 0) keyComponents++;
            
            // Need at least 3 key components by ante 5
            if (keyComponents < 3) {
                return 0;
            }
            
            // Add final bonuses for completed synergies
            if (state.hasNegativeLuckyCat && state.hasMagicianBefore3) {
                totalScore += 100; // Perfect Lucky Cat setup
            }
            
            if (state.negativeTagsConsecutive >= 2) {
                totalScore += 75; // Multiple consecutive neg tags
            }
            
            if (state.spectralNegLegendaries >= 2) {
                totalScore += 120; // Multiple negative tarots
            }
            
            if (state.anteOfTelescopeVoucher > 0 && state.hasTheArchitect) {
                totalScore += 80; // Telescope + Architect combo
            }
        }
    }
    
    return totalScore;
}