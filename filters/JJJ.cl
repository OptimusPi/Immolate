#include "lib/immolate.cl"

// JJJ - A filter to find seeds with an Erratic Deck containing many Jacks,
// plus specific combinations of jokers and items before ante 3

typedef struct {
    // Required items tracking
    bool found_hit_the_road;   // Hit_the_Road joker
    bool found_turtle_bean;    // Turtle_Bean joker
    bool found_perkeo;         // Perkeo joker
    bool found_cryptid;        // Cryptid spectral item (from shop only)
    bool found_immolate;       // Immolate spectral item
    bool found_faceless;       // Faceless_Joker
    
    // Showman tracking for duplicates
    bool hasShowman;
    
    // Game context
    instance *inst;
    int ante;
    long jacks_count;           // Number of Jacks in the deck
} game_state;

// Initialize the game state
void init_game_state(game_state *state, instance *inst) {
    state->found_hit_the_road = false;
    state->found_turtle_bean = false;
    state->found_perkeo = false;
    state->found_cryptid = false;
    state->found_immolate = false;
    state->found_faceless = false;
    state->hasShowman = false;
    state->inst = inst;
    state->ante = 1;
    state->jacks_count = 0;
}

// Check if all requirements are met
bool requirements_met_start(game_state *state) {
    return (state->found_hit_the_road && 
            state->found_turtle_bean);
}


// Check if all requirements are met
bool requirements_met_total(game_state *state) {
    return (
            state->found_turtle_bean && 
            state->found_perkeo && 
            state->found_cryptid && 
            state->found_immolate &&
            state->found_faceless);
}

// Process a joker card
void process_joker(jokerdata joker, game_state *state) {
    // Skip if we're past ante 3 (we only care about jokers found before ante 3)
    if (state->ante > 3) {
        return;
    }
    
    // Check for duplicate jokers (only allowed if we have Showman)
    if (!state->hasShowman) {
        if ((joker.joker == Hit_the_Road && state->found_hit_the_road) ||
            (joker.joker == Turtle_Bean && state->found_turtle_bean) ||
            (joker.joker == Perkeo && state->found_perkeo) ||
            (joker.joker == Faceless_Joker && state->found_faceless)) {
            return;
        }
    }
    
    // Check for required jokers
    switch (joker.joker) {
        case Hit_the_Road:
            state->found_hit_the_road = true;
            break;
            
        case Turtle_Bean:
            state->found_turtle_bean = true;
            break;
            
        case Perkeo:
            state->found_perkeo = true;
            break;
            
        case Faceless_Joker:
            state->found_faceless = true;
            break;
            
        case Showman:
            if (!state->hasShowman) {
                state->hasShowman = true;
                state->inst->params.showman = true; // Enable duplicate jokers
            }
            break;
            
        default:
            break;
    }
}

// Process a spectral item from shop (only these count for Cryptid/Immolate requirements)
void process_shop_spectral(item spectral, game_state *state) {
    // Skip if we're past ante 3 (we only care about items found before ante 3)
    if (state->ante > 3) {
        return;
    }
    
    // Check for required spectral items
    if (spectral == Cryptid) {
        state->found_cryptid = true;
    } else if (spectral == Immolate) {
        state->found_immolate = true;
    }
}

// Check shop items for ante
void check_shop_items(game_state *state, int count) {
    for (int i = 0; i < count; i++) {
        shopitem item = next_shop_item(state->inst, state->ante);
        
        if (item.type == ItemType_Joker) {
            process_joker(item.joker, state);
        } else if (item.type == ItemType_Spectral) {
            process_shop_spectral(item.value, state);
        }
    }
}

// Check packs for ante - only looking for jokers from packs, not spectral items
void check_packs(game_state *state, int count) {
    for (int i = 0; i < count; i++) {
        pack p = pack_info(next_pack(state->inst, state->ante));
        
        if (p.type == Buffoon_Pack) {
            // Process jokers from Buffoon pack
            jokerdata jokers[5];
            buffoon_pack_detailed(jokers, p.size, state->inst, state->ante);
            for (int j = 0; j < p.size; j++) {
                process_joker(jokers[j], state);
            }
        } else if (p.type == Spectral_Pack) {
            // Process items from Spectral pack - only looking for The_Soul
            item items[5];
            spectral_pack(items, p.size, state->inst, state->ante);
            for (int j = 0; j < p.size; j++) {
                if (items[j] == The_Soul) {
                    // Handle The Soul
                    jokerdata jkr = next_joker_with_info(state->inst, S_Soul, state->ante);
                    process_joker(jkr, state);
                }
                // We don't check for Cryptid or Immolate in packs since they can't be kept in inventory
            }
        }
    }
}

// Count Jacks in the deck
long count_jacks(item deck[52]) {
    long jack_count = 0;
    for (int i = 0; i < 52; i++) {
        item r = rank(deck[i]);
        if (r == Jack) {
            jack_count++;
        }
    }
    return jack_count;
}

// Main filter function
long filter(instance *inst) {
    // Set up the erratic deck
    set_deck(inst, Erratic_Deck);
    item deck[52];
    init_deck(inst, deck);
    
    // Initialize game state
    game_state state;
    init_game_state(&state, inst);
    state.inst = inst;
    
    // Count Jacks in the deck (this is our potential score)
    state.jacks_count = count_jacks(deck);
    if (state.jacks_count < 5) {
        return 0; // No Jacks, no point in continuing
    }
    
    // Examine each ante up to 3
    for (int ante = 1; ante <= 8; ante++) {
        state.ante = ante;
        
        // Check shop items
        check_shop_items(&state, 10); // Check 10 shop items per ante
        
        // Check packs
        check_packs(&state, 4); // Check 4 packs per ante
        
        // Burn an orbital tag call for RNG consistency
        next_orbital_tag(inst);
        next_tag(inst, ante);
        next_tag(inst, ante);
        if (ante == 2 && !requirements_met_start(&state)) {
            return 0;
        }
    }
    
    // If all requirements are met, return the number of Jacks
    // Otherwise, return 0
    if (requirements_met_total(&state)) {
        return state.jacks_count;
    } else {
        return 0;
    }
}