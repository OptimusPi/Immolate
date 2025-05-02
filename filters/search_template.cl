#define CACHE_SIZE 1000
#include "lib/immolate.cl"

// ==========================================
// SEARCH TEMPLATE - CONFIGURABLE PARAMETERS
// ==========================================

// Target items to search for (set up to 10 desired items)
// The item you're looking for (Joker, Spectral, Arcana, etc.)
__constant item TARGET_ITEMS[10] = {
    Showman,        // Item 1
    Blueprint,      // Item 2
    The_Soul,       // Item 3
    Space_Joker,    // Item 4
    Smeared_Joker,  // Item 5
    Oops_All_6s,    // Item 6
    Voucher_Tag,    // Item 7
    Bloodstone,     // Item 8
    Lusty_Joker,    // Item 9
    Four_Fingers    // Item 10
};

// Item flags (define specific conditions for each item)
// 0 = No special flags
// 1 = Must be negative edition
// 2 = Any edition is fine, but negative gets bonus points
// 3 = Must be from specific pack type (see ITEM_SOURCE)
// 4 = Prefer multiple instances (add score for each)
// Custom flags can be defined as needed
__constant int ITEM_FLAGS[10] = {
    0,  // Item 1 flags 
    1,  // Item 2 flags
    0,  // Item 3 flags
    0,  // Item 4 flags
    0,  // Item 5 flags
    2,  // Item 6 flags
    0,  // Item 7 flags
    4,  // Item 8 flags
    4,  // Item 9 flags
    0   // Item 10 flags
};

// Score values for each item
__constant int ITEM_SCORES[10] = {
    10000,  // Item 1 score
    5000,   // Item 2 score
    2000,   // Item 3 score
    1000,   // Item 4 score
    1000,   // Item 5 score
    3000,   // Item 6 score
    500,    // Item 7 score
    500,    // Item 8 score
    500,    // Item 9 score
    1000    // Item 10 score
};

// Source for checking items (relevant for spectral, arcana, etc.)
// 0 = Any source
// 1 = Specific source (like packs, see PACK_TYPES)
__constant int ITEM_SOURCE[10] = {
    0,  // Item 1 source
    0,  // Item 2 source
    1,  // Item 3 source
    0,  // Item 4 source
    0,  // Item 5 source
    0,  // Item 6 source
    0,  // Item 7 source
    0,  // Item 8 source
    0,  // Item 9 source
    0   // Item 10 source
};

// Required pack types (only used if ITEM_SOURCE is 1)
__constant item PACK_TYPES[10] = {
    0,              // Item 1 pack type
    0,              // Item 2 pack type
    Spectral_Pack,  // Item 3 pack type
    0,              // Item 4 pack type
    0,              // Item 5 pack type
    0,              // Item 6 pack type
    0,              // Item 7 pack type
    0,              // Item 8 pack type
    0,              // Item 9 pack type
    0               // Item 10 pack type
};

// Bonus score for negative edition (only if flag = 2)
__constant int NEGATIVE_BONUS = 5000;

// Deck and stake
__constant item DECK = Ghost_Deck;
__constant item STAKE = Black_Stake;

// Maximum ante to check
__constant int MAX_ANTE = 12;

// Enable Showman logic (set to false to disable)
__constant bool USE_SHOWMAN_LOGIC = true;

// Only accept items in specific ante range
__constant int MIN_ANTE_REQUIRED = 1;  // Minimum ante to consider the item
__constant int MAX_ANTE_REQUIRED = 12; // Maximum ante to consider the item

// ==========================================
// IMPLEMENTATION - DON'T MODIFY BELOW HERE
// ==========================================

typedef struct {
    bool itemFound[10];        // Tracks if each item was found
    bool itemNegative[10];     // Tracks if item was negative
    int itemCount[10];         // Count of each item (for multiple scoring)
    bool hasShowman;           // Tracks if Showman has been found
    bool showmanNegative;      // If Showman is negative
    int totalScore;            // Total score for this seed
    instance *inst;            // Instance for this search
    int currentAnte;           // Current ante being checked
    bool validSeed;            // If this seed meets minimum requirements
} search_state;

int checkItem(item foundItem, item edition, int itemIndex, search_state *state) {
    if (foundItem != TARGET_ITEMS[itemIndex]) return 0;
    
    int score = 0;
    bool isNegative = (edition == Negative);
    int flags = ITEM_FLAGS[itemIndex];
    
    // Check if we've already found this item (but not for multiple counting)
    if (state->itemFound[itemIndex] && flags != 4) return 0;
    
    // Handle Showman specially
    if (foundItem == Showman && !state->hasShowman) {
        state->hasShowman = true;
        state->showmanNegative = isNegative;
        state->inst->params.showman = true;
    }
    
    // Check flags
    if (flags == 1 && !isNegative) return 0;  // Must be negative
    
    // Calculate score based on flags
    if (flags == 2 && isNegative) {
        score = ITEM_SCORES[itemIndex] + NEGATIVE_BONUS;  // Bonus for negative
    } else {
        score = ITEM_SCORES[itemIndex];
    }
    
    // Apply Showman logic if enabled
    if (USE_SHOWMAN_LOGIC && !state->hasShowman && 
        state->currentAnte > 2 && itemIndex > 0) {
        // Without Showman, we only count the first instance of non-multiple items
        if (flags != 4 && state->itemFound[itemIndex]) return 0;
    }
    
    // Mark item as found and count it
    state->itemFound[itemIndex] = true;
    if (isNegative) state->itemNegative[itemIndex] = true;
    state->itemCount[itemIndex]++;
    
    // If valid ante range is specified, check it
    if (state->currentAnte < MIN_ANTE_REQUIRED ||
        state->currentAnte > MAX_ANTE_REQUIRED) {
        return 0;
    }
    
    // We found a valid item, mark the seed as valid
    state->validSeed = true;
    
    return score;
}

int checkTag(search_state *state) {
    item tag = next_tag(state->inst, state->currentAnte);
    
    for (int i = 0; i < 10; i++) {
        if (TARGET_ITEMS[i] == tag) {
            return checkItem(tag, No_Edition, i, state);
        }
    }
    
    return 0;
}

int checkVoucher(search_state *state) {
    item voucher = next_voucher(state->inst, state->currentAnte);
    
    for (int i = 0; i < 10; i++) {
        if (TARGET_ITEMS[i] == voucher) {
            return checkItem(voucher, No_Edition, i, state);
        }
    }
    
    return 0;
}

int checkShopItem(search_state *state) {
    shopitem sItem = next_shop_item(state->inst, state->currentAnte);
    item itemValue = sItem.value;
    item edition = No_Edition;
    
    if (sItem.type == ItemType_Joker) {
        edition = sItem.joker.edition;
    }
    
    for (int i = 0; i < 10; i++) {
        if (TARGET_ITEMS[i] == itemValue) {
            return checkItem(itemValue, edition, i, state);
        }
    }
    
    return 0;
}

int checkBuffoonPack(search_state *state, pack packInfo) {
    jokerdata jokers[5];
    buffoon_pack_detailed(jokers, packInfo.size, state->inst, state->currentAnte);
    
    int score = 0;
    for (int j = 0; j < packInfo.size; j++) {
        item joker = jokers[j].joker;
        item edition = jokers[j].edition;
        
        for (int i = 0; i < 10; i++) {
            if (TARGET_ITEMS[i] == joker) {
                int sourceCheck = ITEM_SOURCE[i];
                if (sourceCheck == 1 && PACK_TYPES[i] != Buffoon_Pack) continue;
                
                score += checkItem(joker, edition, i, state);
            }
        }
    }
    
    return score;
}

int checkSpectralPack(search_state *state, pack packInfo) {
    item cards[5];
    spectral_pack(cards, packInfo.size, state->inst, state->currentAnte);
    
    int score = 0;
    for (int j = 0; j < packInfo.size; j++) {
        item card = cards[j];
        
        // Special handling for The Soul (gets joker info)
        if (card == The_Soul) {
            for (int i = 0; i < 10; i++) {
                if (TARGET_ITEMS[i] == The_Soul) {
                    int sourceCheck = ITEM_SOURCE[i];
                    if (sourceCheck == 1 && PACK_TYPES[i] != Spectral_Pack) continue;
                    
                    jokerdata soul = next_joker_with_info(state->inst, S_Soul, state->currentAnte);
                    score += checkItem(soul.joker, soul.edition, i, state);
                }
            }
        } else {
            // Regular spectral card
            for (int i = 0; i < 10; i++) {
                if (TARGET_ITEMS[i] == card) {
                    int sourceCheck = ITEM_SOURCE[i];
                    if (sourceCheck == 1 && PACK_TYPES[i] != Spectral_Pack) continue;
                    
                    score += checkItem(card, No_Edition, i, state);
                }
            }
        }
    }
    
    return score;
}

int checkArcanaPack(search_state *state, pack packInfo) {
    item cards[5];
    arcana_pack(cards, packInfo.size, state->inst, state->currentAnte);
    
    int score = 0;
    for (int j = 0; j < packInfo.size; j++) {
        item card = cards[j];
        
        for (int i = 0; i < 10; i++) {
            if (TARGET_ITEMS[i] == card) {
                int sourceCheck = ITEM_SOURCE[i];
                if (sourceCheck == 1 && PACK_TYPES[i] != Arcana_Pack) continue;
                
                score += checkItem(card, No_Edition, i, state);
            }
        }
    }
    
    return score;
}

int checkPack(search_state *state) {
    item packItem = next_pack(state->inst, state->currentAnte);
    pack packInfo = pack_info(packItem);
    
    // Process different pack types
    switch (packInfo.type) {
        case Buffoon_Pack:
        case Jumbo_Buffoon_Pack:
        case Mega_Buffoon_Pack:
            return checkBuffoonPack(state, packInfo);
            
        case Spectral_Pack:
        case Jumbo_Spectral_Pack:
        case Mega_Spectral_Pack:
            return checkSpectralPack(state, packInfo);
            
        case Arcana_Pack:
        case Jumbo_Arcana_Pack:
        case Mega_Arcana_Pack:
            return checkArcanaPack(state, packInfo);
            
        default:
            return 0;  // Standard packs not handled
    }
}

long filter(instance* inst) {
    // Set up the deck and stake
    set_deck(inst, DECK);
    set_stake(inst, STAKE);
    init_locks(inst, 1, false, true);
    
    // Initialize the search state
    search_state state = {0};
    state.inst = inst;
    state.hasShowman = false;
    state.totalScore = 0;
    state.validSeed = false;
    
    // Reset all counters
    for (int i = 0; i < 10; i++) {
        state.itemFound[i] = false;
        state.itemNegative[i] = false;
        state.itemCount[i] = 0;
    }
    
    // Search through each ante
    for (int ante = 1; ante <= MAX_ANTE; ante++) {
        state.currentAnte = ante;
        init_unlocks(inst, ante, false);
        
        // Check tags (two per ante)
        state.totalScore += checkTag(&state);
        state.totalScore += checkTag(&state);
        
        // Burn boss blind call
        next_orbital_tag(inst);
        
        // Check voucher
        state.totalScore += checkVoucher(&state);
        
        // Check shop items (6 per ante)
        int shopItems = 6;
        for (int i = 0; i < shopItems; i++) {
            state.totalScore += checkShopItem(&state);
        }
        
        // Check packs (4 for ante 1, 6 for other antes)
        int numPacks = (ante == 1) ? 4 : 6;
        for (int i = 0; i < numPacks; i++) {
            state.totalScore += checkPack(&state);
        }
    }
    
    // Return 0 if not a valid seed (didn't meet minimum requirements)
    if (!state.validSeed) return 0;
    
    // Return total score for this seed
    return state.totalScore;
}