#include "lib/immolate.cl"
#define CACHE_SIZE 2000
#define FIXED_FILTER_CUTOFF

// Game state to track requirements and scoring
typedef struct {
    bool hasPerkeo;
    int perkeoAnte;
    bool hasTelescope;
    int telescopeAnte;
    bool hasObservatory;
    int observatoryAnte;
    bool hasLuckyCat;
    int luckyCatAnte;
    bool hasBlank;
    bool hasAntimatter;
    int blueprints;
    int brainstorms;
    int oopsAll6s;
    int spaceJokers;
    bool hasDna;
    int desirednegatives;
    int randomnegatives;
    int negTagsL;
    int negTagsR;
    instance *inst;
} game_state;

// Initialize the game state
void init_game_state(game_state *state, instance *inst) {
    state->hasPerkeo = false;
    state->perkeoAnte = 0;
    state->hasTelescope = false;
    state->telescopeAnte = 0;
    state->hasObservatory = false;
    state->observatoryAnte = 0;
    state->hasLuckyCat = false;
    state->luckyCatAnte = 0;
    state->hasBlank = false;
    state->hasAntimatter = false;
    state->blueprints = 0;
    state->brainstorms = 0;
    state->oopsAll6s = 0;
    state->spaceJokers = 0;
    state->hasDna = false;
    state->inst = inst;
    state->desirednegatives = 0;
    state->randomnegatives = 0;
    state->negTagsL = 0;
    state->negTagsR = 0;
}

// Check if requirements are met
bool requirements_met(game_state *state) {
    if (!state->hasPerkeo) {
        return false;
    }
    
    if (!state->hasTelescope) {
        return false;
    }
    
    if (!state->hasObservatory) {
        return false;
    }
    
    if (!state->hasLuckyCat) {
        return false;
    }

    if (!state->hasAntimatter) {
        return false;
    }
    
    return true;
}

// Process a joker and update game state
void process_joker(jokerdata joker, game_state *state, int ante) {
    // Set showman parameter when Showman joker is found
    if (joker.joker == Showman) {
        state->inst->params.showman = true;
    }
    
    bool desiredNegative = true;

    // Handle specific jokers we care about
    switch (joker.joker) {
        case Perkeo:
            if (!state->hasPerkeo) {
                state->hasPerkeo = true;
                state->perkeoAnte = ante;
            }
            break;
            
        case Lucky_Cat:
            if (!state->hasLuckyCat) {
                state->hasLuckyCat = true;
                state->luckyCatAnte = ante;
            }
            break;
            
        case Blueprint:
            state->blueprints++;
            break;
            
        case Brainstorm:
            state->brainstorms++;
            break;
            
        case Oops_All_6s:
            state->oopsAll6s++;
            break;
            
        case Space_Joker:
            state->spaceJokers++;
            break;
            
        case DNA:
            state->hasDna = true;
            break;
            
        default:
            desiredNegative = false;
            break;
    }

    if (joker.edition == Negative) {
        if (desiredNegative == true) {
            state->desirednegatives++;
        } else {
            state->randomnegatives++;
        }
    }
}

// Check vouchers from packs and other sources (not shops)
void check_voucher(game_state *state, int ante) {
        // Vouchers are obtained from packs, not shops
    item voucher = next_voucher(state->inst, ante);
    
    if (voucher == Telescope) {
        if (!state->hasTelescope) {
            state->hasTelescope = true;
            state->telescopeAnte = ante;
        }
    } else if (voucher == Observatory) {
        if (state->hasTelescope && !state->hasObservatory) {
            state->hasObservatory = true;
            state->observatoryAnte = ante;
        }
    } else if (voucher == Blank) {
        state->hasBlank = true;
    } else if (voucher == Antimatter) {
        state->hasAntimatter = true;
    } 
    activate_voucher(state->inst, voucher);
}

// Check shop items for ante
void check_shop_items(game_state *state, int ante, int count) {
    for (int i = 0; i < count; i++) {
        shopitem item = next_shop_item(state->inst, ante);
        if (item.type == ItemType_Joker) {
            process_joker(item.joker, state, ante);
        }
    }
}

// Check packs for ante
void check_packs(game_state *state, int ante, int count) {
    for (int i = 0; i < count; i++) {
        pack p = pack_info(next_pack(state->inst, ante));
        
        if (p.type == Buffoon_Pack) {
            // Process jokers from Buffoon pack
            jokerdata jokers[5];
            buffoon_pack_detailed(jokers, p.size, state->inst, ante);
            for (int j = 0; j < p.size; j++) {
                process_joker(jokers[j], state, ante);
            }
        } else if (p.type == Spectral_Pack) {
            // Process items from Spectral pack
            item items[5];
            spectral_pack(items, p.size, state->inst, ante);
            for (int j = 0; j < p.size; j++) {
                if (items[j] == The_Soul) {
                    // Handle The Soul (could be Perkeo)
                    jokerdata jkr = next_joker_with_info(state->inst, S_Soul, ante);
                    process_joker(jkr, state, ante);
                }
            }
        }
    }
}

// Calculate final score
long calculate_score(game_state *state) {
    const int digit1 = 100000;
    const int digit2 = 10000;
    const int digit3 = 1000;
    const int digit4 = 100;
    const int digit5 = 10;
    const int digit6 = 1;

    // Base score starts with joker capacity
    long score = state->desirednegatives
                                * digit1;
    score += state->randomnegatives
                                * digit2;
    score += state->negTagsL    ? digit3 : 0;
    score += state->negTagsR    ? digit4 : 0;
    score += (state->blueprints
        + state->brainstorms)   * digit5;
    // otherwise new column score
    score += state->oopsAll6s   * digit6;

    return score;
}

// Main filter function
long filter(instance *inst) {
    set_deck(inst, Ghost_Deck);
    set_stake(inst, Black_Stake);
    init_locks(inst, 1, false, false);
    
    game_state state;
    init_game_state(&state, inst);
    
    // Examine each ante progressively
    for (int ante = 1; ante <= 10; ante++) {
        init_unlocks(state.inst, ante, false);
        if (next_tag(state.inst, ante) == Negative_Tag)
            state.negTagsL++;
        if (next_tag(state.inst, ante) == Negative_Tag)
            state.negTagsR++;

        //Burn function call
        next_orbital_tag(state.inst);
        
        // Process shop items and packs with adjusted counts
        // Higher ante gets more attention in early rounds
        int shop_count = (ante == 1) ? 4 : 6;
        int pack_count = (ante == 1) ? 4 : (ante <= 3) ? 6 : 4; // Reduce pack checking in later antes
        
        check_shop_items(&state, ante, shop_count);
        check_packs(&state, ante, pack_count);
        check_voucher(&state, ante);
        
        // Early exit conditions - check after each ante if we can't possibly meet requirements
        if (ante >= 3 && !state.hasPerkeo) {
            return 0; // No Perkeo by ante 4, exit early
        }
        
        if (ante >= 6 && !state.hasTelescope) {
            return 0; // No Telescope by ante 5, exit early
        }
        
        if (ante >= 7 && !state.hasLuckyCat) {
            return 0; // No Lucky Cat by ante 6, exit early
        }
    }
    if (!requirements_met(&state)) {
        return 0;
    }
    
    // Calculate final score
    long finalScore = calculate_score(&state);
    return finalScore;
}