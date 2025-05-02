#include "lib/immolate.cl"

// JesterQuest - A filter that hunts for themed joker collections
// Designed to find seeds with specific joker combinations that match various
// "deck archetypes" from Balatro - each with its own scoring criteria.

typedef struct {
    // Joker tracking
    bool jokers[J_END];  // Tracks all jokers found
    int jokerCount;      // Total jokers found
    int negativeCount;   // Number of negative jokers found
    
    // Themed deck trackers
    int luckScore;       // For luck-based builds
    int flushScore;      // For flush-based builds
    int legendaryScore;  // For collecting legendary jokers
    int pokerHandScore;  // For poker hand manipulation builds
    int moneyScore;      // For money-focused builds
    int diceFocusScore;  // For dice manipulation builds

    // Game context
    instance *inst;
    int ante;
    bool hasShowman;     // Tracks if the seed has showman (allows dupes)
} game_state;

// Initialize the game state
void init_game_state(game_state *state, instance *inst) {
    for (int i = 0; i < J_END; i++) {
        state->jokers[i] = false;
    }
    state->jokerCount = 0;
    state->negativeCount = 0;
    state->luckScore = 0;
    state->flushScore = 0;
    state->legendaryScore = 0;
    state->pokerHandScore = 0;
    state->moneyScore = 0;
    state->diceFocusScore = 0;
    state->inst = inst;
    state->ante = 1;
    state->hasShowman = false;
}

// Score a joker based on various themed decks
void score_joker(item joker, item edition, game_state *state) {
    // Don't count duplicates unless we have Showman
    if (state->jokers[joker] && !state->hasShowman) {
        return;
    }
    
    // Mark this joker as found
    state->jokers[joker] = true;
    state->jokerCount++;
    
    // Track negative edition jokers
    if (edition == Negative) {
        state->negativeCount++;
    }
    
    // Check for Showman (allows duplicates)
    if (joker == Showman) {
        state->hasShowman = true;
        state->inst->params.showman = true;
    }
    
    // Score for luck-based builds
    if (joker == Lucky_Cat || joker == _8_Ball || joker == Golden_Ticket || 
        joker == Lucky_Card || joker == Rabbit_Foot || joker == Four_Leaf_Clover) {
        state->luckScore += (edition == Negative) ? 5 : 2;
    }
    
    // Score for flush-based builds
    if (joker == Flush || joker == Straight_Flush || joker == Flush_Five ||
        joker == Straight || joker == The_Duo || joker == The_Trio ||
        joker == The_Family || joker == The_Order || joker == The_Tribe) {
        state->flushScore += (edition == Negative) ? 6 : 3;
    }
    
    // Score for legendary jokers
    if (joker >= J_L_BEGIN && joker <= J_L_END) {
        // Legendary jokers are extremely valuable
        state->legendaryScore += (edition == Negative) ? 50 : 20;
    }
    
    // Score for poker hand manipulation
    if (joker == Pair || joker == Two_Pair || joker == Three_of_a_Kind ||
        joker == Four_of_a_Kind || joker == Five_of_a_Kind || joker == Full_House) {
        state->pokerHandScore += (edition == Negative) ? 5 : 2;
    }
    
    // Score for money-focused builds
    if (joker == Credit_Card || joker == Greedy_Joker || joker == Business_Card ||
        joker == Midas_Mask || joker == Golden_Joker || joker == Gold_Card) {
        state->moneyScore += (edition == Negative) ? 5 : 2;
    }
    
    // Score for dice manipulation builds
    if (joker == Oops_All_6s || joker == Even_Steven || joker == Odd_Todd ||
        joker == Luchador || joker == D6_Tag) {
        state->diceFocusScore += (edition == Negative) ? 5 : 2;
    }
}

// Process a joker card and update the game state
void process_joker(jokerdata joker, game_state *state) {
    score_joker(joker.joker, joker.edition, state);
}

// Check shop items for ante
void check_shop_items(game_state *state, int count) {
    for (int i = 0; i < count; i++) {
        shopitem item = next_shop_item(state->inst, state->ante);
        
        if (item.type == ItemType_Joker) {
            process_joker(item.joker, state);
        }
    }
}

// Check packs for ante
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
            // Process items from Spectral pack
            item items[5];
            spectral_pack(items, p.size, state->inst, state->ante);
            for (int j = 0; j < p.size; j++) {
                if (items[j] == The_Soul) {
                    // Handle The Soul
                    jokerdata jkr = next_joker_with_info(state->inst, S_Soul, state->ante);
                    process_joker(jkr, state);
                }
            }
        }
    }
}

// Calculate the overall score based on various builds
long calculate_score(game_state *state) {
    // Find the highest themed score
    int bestThemeScore = max(state->luckScore, 
                          max(state->flushScore,
                          max(state->legendaryScore,
                          max(state->pokerHandScore,
                          max(state->moneyScore,
                          state->diceFocusScore)))));
    
    // Base score is the best theme score multiplied by total jokers found
    long score = bestThemeScore * state->jokerCount;
    
    // Add bonus for negative jokers
    score += state->negativeCount * 25;
    
    // Add bonus for showman (allows duplicates)
    if (state->hasShowman) {
        score += 100;
    }
    
    // Add bonus if we found a legendary joker
    if (state->legendaryScore > 0) {
        score += 200;
    }
    
    // Add bonus if we found negative legendaries
    if (state->legendaryScore > 20) {
        score += 500;
    }
    
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
        state.ante = ante;
        
        // Process shop items
        check_shop_items(&state, 10);
        
        // Process packs
        check_packs(&state, 6);
        
        // Burn an orbital tag call for RNG consistency
        next_orbital_tag(inst);
        next_tag(inst, ante);
        next_tag(inst, ante);
    }
    
    // Calculate final score
    return calculate_score(&state);
}