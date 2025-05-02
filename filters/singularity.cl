#include "lib/immolate.cl"

// Game state to track requirements and scoring
typedef struct {
    bool hasDietCola;
    bool hasDietColaAnte1;
    bool hasAnkh;
    int ankhCount;
    bool hasPerkeo;
    bool hasBlueprint;
    bool hasBrainstorm;
    bool hasShowman;
    bool hasOopsAll6s;
    bool hasLuckyCat;
    int negativeTags;
    int premiumNegatives;
    int dietColaSellCount;
    bool skipNextRound;
    bool tagPending;
    int ankhFoundAnte;
    int perkeoFoundAnte;
    int blueprintFoundAnte;
    int brainstormFoundAnte;
    int showmanFoundAnte;
    instance *inst;
} game_state;

// Initialize the game state
void init_game_state(game_state *state, instance *inst) {
    state->hasDietCola = false;
    state->hasDietColaAnte1 = false;
    state->hasAnkh = false;
    state->ankhCount = 0;
    state->hasPerkeo = false;
    state->hasBlueprint = false;
    state->hasBrainstorm = false;
    state->hasShowman = false;
    state->hasOopsAll6s = false;
    state->hasLuckyCat = false;
    state->negativeTags = 0;
    state->premiumNegatives = 0;
    state->dietColaSellCount = 0;
    state->skipNextRound = false;
    state->tagPending = false;
    state->ankhFoundAnte = 0;
    state->perkeoFoundAnte = 99;
    state->blueprintFoundAnte = 0;
    state->brainstormFoundAnte = 0;
    state->showmanFoundAnte = 0;
    state->inst = inst;
}

// Check if base requirements are met
bool requirements_met(game_state *state) {
    // Diet Cola must be in ante 1
    if (!state->hasDietColaAnte1) {
        return false;
    }
    
    // Need at least one Ankh before Perkeo
    if (!state->hasAnkh || (state->hasPerkeo && state->ankhFoundAnte > state->perkeoFoundAnte)) {
        return false;
    }
    
    return true;
}

// Check if a joker is a premium target for negative tag
bool is_premium_joker(int joker) {
    switch (joker) {
        case Blueprint:
        case Brainstorm:
        case Showman:
        case Oops_All_6s:
        case Lucky_Cat:
        case Hack:
        case Raised_Fist:
        case Gros_Michel:
        case Acrobat:
            return true;
        default:
            return false;
    }
}

// Calculate how many Perkeo triggers per round based on ownership of Blueprint/Brainstorm
int get_perkeo_triggers_per_round(game_state *state, int ante) {
    // Base case: Perkeo triggers once at the end of each shopping phase
    int triggers = 1;
    
    // Additional triggers from Blueprint/Brainstorm
    if (state->hasBlueprint && state->blueprintFoundAnte <= ante) {
        triggers++;
    }
    
    if (state->hasBrainstorm && state->brainstormFoundAnte <= ante) {
        triggers++;
    }
    
    return triggers;
}

// Process a joker and update game state
void process_joker(jokerdata joker, game_state *state, int ante, int round) {
    // Handle specific jokers we care about
    switch (joker.joker) {
        case Perkeo:
            if (!state->hasPerkeo) {
                state->hasPerkeo = true;
                state->perkeoFoundAnte = ante;
                
                // Calculate Ankh duplication potential if we have Ankh
                if (state->hasAnkh) {
                    // Calculate potential for current round
                    int current_round_triggers = get_perkeo_triggers_per_round(state, ante) * (3 - round + 1);
                    
                    // Calculate potential for future rounds
                    int future_triggers = 0;
                    for (int future_ante = ante + 1; future_ante <= 8; future_ante++) {
                        future_triggers += get_perkeo_triggers_per_round(state, future_ante) * 3;
                    }
                    
                    // Total triggers
                    int total_triggers = current_round_triggers + future_triggers;
                    
                    // Each trigger potentially doubles Ankh count
                    for (int i = 0; i < total_triggers; i++) {
                        state->ankhCount *= 2;
                    }
                }
            }
            break;
            
        case Diet_Cola:
            state->hasDietCola = true;
            if (ante == 1) {
                state->hasDietColaAnte1 = true;
            }
            break;
            
        case Blueprint:
            if (!state->hasBlueprint) {
                state->hasBlueprint = true;
                state->blueprintFoundAnte = ante;
                
                // If we already have Perkeo and Ankh, recalculate duplication
                if (state->hasPerkeo && state->hasAnkh) {
                    // Reset count to start fresh
                    state->ankhCount = 1;
                    
                    // Calculate current round triggers
                    int current_round_triggers = get_perkeo_triggers_per_round(state, ante) * (3 - round + 1);
                    
                    // Calculate future triggers
                    int future_triggers = 0;
                    for (int future_ante = ante + 1; future_ante <= 8; future_ante++) {
                        future_triggers += get_perkeo_triggers_per_round(state, future_ante) * 3;
                    }
                    
                    // Apply duplication
                    int total_triggers = current_round_triggers + future_triggers;
                    for (int i = 0; i < total_triggers; i++) {
                        state->ankhCount *= 2;
                    }
                }
            }
            break;
            
        case Brainstorm:
            if (!state->hasBrainstorm) {
                state->hasBrainstorm = true;
                state->brainstormFoundAnte = ante;
                
                // If we already have Perkeo and Ankh, recalculate duplication
                if (state->hasPerkeo && state->hasAnkh) {
                    // Reset count to start fresh
                    state->ankhCount = 1;
                    
                    // Calculate current round triggers
                    int current_round_triggers = get_perkeo_triggers_per_round(state, ante) * (3 - round + 1);
                    
                    // Calculate future triggers
                    int future_triggers = 0;
                    for (int future_ante = ante + 1; future_ante <= 8; future_ante++) {
                        future_triggers += get_perkeo_triggers_per_round(state, future_ante) * 3;
                    }
                    
                    // Apply duplication
                    int total_triggers = current_round_triggers + future_triggers;
                    for (int i = 0; i < total_triggers; i++) {
                        state->ankhCount *= 2;
                    }
                }
            }
            break;
            
        case Showman:
            if (!state->hasShowman) {
                state->hasShowman = true;
                state->showmanFoundAnte = ante;
                
                // Set showman parameter in the instance to allow duplicate jokers
                state->inst->params.showman = true;
            }
            break;
            
        case Oops_All_6s:
            state->hasOopsAll6s = true;
            break;
            
        case Lucky_Cat:
            state->hasLuckyCat = true;
            break;
            
        default:
            break;
    }
    
    // Track premium negative jokers
    if (joker.edition == Negative && is_premium_joker(joker.joker)) {
        state->premiumNegatives++;
    }
}

// Check shop items for ante
void check_shop_items(game_state *state, int ante, int round, int count) {
    for (int i = 0; i < count; i++) {
        shopitem item = next_shop_item(state->inst, ante);
        
        if (item.type == ItemType_Joker) {
            process_joker(item.joker, state, ante, round);
        }
        else if (item.type == ItemType_Spectral && item.value == Ankh) {
            if (!state->hasAnkh) {
                state->hasAnkh = true;
                state->ankhFoundAnte = ante;
                state->ankhCount = 1;
            } else {
                // If we already have Ankh and found another one
                state->ankhCount++;
            }
        }
    }
}

// Check packs for ante
void check_packs(game_state *state, int ante, int round, int count) {
    for (int i = 0; i < count; i++) {
        pack p = pack_info(next_pack(state->inst, ante));
        
        if (p.type == Buffoon_Pack) {
            // Process jokers from Buffoon pack
            jokerdata jokers[5];
            buffoon_pack_detailed(jokers, p.size, state->inst, ante);
            for (int j = 0; j < p.size; j++) {
                process_joker(jokers[j], state, ante, round);
            }
        } else if (p.type == Spectral_Pack) {
            // Process items from Spectral pack
            item items[5];
            spectral_pack(items, p.size, state->inst, ante);
            for (int j = 0; j < p.size; j++) {
                if (items[j] == The_Soul) {
                    // Handle The Soul
                    jokerdata jkr = next_joker_with_info(state->inst, S_Soul, ante);
                    process_joker(jkr, state, ante, round);
                }
                else if (items[j] == Ankh) {
                    if (!state->hasAnkh) {
                        state->hasAnkh = true;
                        state->ankhFoundAnte = ante;
                        state->ankhCount = 1;
                    } else {
                        // If we already have Ankh and found another one
                        state->ankhCount++;
                    }
                }
            }
        }
    }
}

// Check tags (special treats from skipping rounds)
bool check_tags(game_state *state, int ante, int round) {
    if (state->tagPending) {
        state->tagPending = false;
        
        // Get the tags (both are the same if we sold Diet_Cola)
        item tag1 = next_tag(state->inst, ante);
        item tag2 = next_tag(state->inst, ante);
        
        // Check if we got a Negative Tag
        if (tag1 == Negative_Tag || tag2 == Negative_Tag) {
            state->negativeTags++;
            return true;
        }
    } else {
        // Just burn the tag calls to maintain RNG sequence
        item tag1 = next_tag(state->inst, ante);
        item tag2 = next_tag(state->inst, ante);
    }
    
    // Get orbital tag (not important for our strategy, but needed for RNG)
    item orbital = next_orbital_tag(state->inst);
    
    return false;
}

// Skip rounds strategically for tag benefits
bool should_skip_round(game_state *state, int ante, int round) {
    // Skip when we have accumulated a lot of Ankh cards
    // This is a simplified heuristic - in a real game, you'd decide based on
    // your current inventory and game state
    if (state->ankhCount >= 4 && state->hasPerkeo && round < 3) {
        // More likely to skip when we have Diet_Cola
        if (state->hasDietCola) {
            // Sell a Diet_Cola to double-trigger the tag
            state->dietColaSellCount++;
            return true;
        }
        
        // Occasionally skip even without Diet_Cola if we have enough Ankh
        if (state->ankhCount >= 8) {
            return true;
        }
    }
    
    return false;
}

// Calculate final score based on maximizing Ankh count and premium negative jokers
long calculate_score(game_state *state) {
    // If requirements aren't met, return 0
    if (!requirements_met(state)) {
        return 0;
    }
    
    // Score is primarily based on the number of Ankh cards
    long score = state->ankhCount * 10;
    
    // Bonus for getting Perkeo early
    if (state->hasPerkeo) {
        score += (8 - state->perkeoFoundAnte);
    }
    
    
    // Bonus for Negative Tags found
    score += state->negativeTags * 10;
    
    // Bonus for premium jokers turned negative
    score += state->premiumNegatives * 100;
    
    // Bonus for Diet_Cola sells (which double-trigger tags)
    score += state->dietColaSellCount * 1000;
    
    return score;
}

// Main filter function
long filter(instance *inst) {
    set_deck(inst, Ghost_Deck);
    set_stake(inst, Black_Stake);
    init_locks(inst, 1, false, false);
    
    game_state state;
    init_game_state(&state, inst);
    
    // Examine each ante up to 8
    for (int ante = 1; ante <= 8; ante++) {
        // Each ante has 3 rounds
        for (int round = 1; round <= 3; round++) {
            init_unlocks(inst, ante, false);
            
            // Check if we should skip this round for a tag benefit
            if (should_skip_round(&state, ante, round)) {
                state.skipNextRound = true;
                state.tagPending = true;
                continue;
            }
            
            // Check tags (from skipped rounds)
            bool got_negative_tag = check_tags(&state, ante, round);
            
            // Check shop items - if we have a Negative_Tag, first joker is free and negative
            int shopItemCount = 10;
            check_shop_items(&state, ante, round, shopItemCount);
            
            // Check packs
            int packCount = 6;
            check_packs(&state, ante, round, packCount);
            
            // Burn an extra orbital tag call - needed to advance RNG correctly
            next_orbital_tag(inst);
        }
    }
    
    // Calculate final score
    return calculate_score(&state);
}
