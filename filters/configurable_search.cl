#define CACHE_SIZE 1000
#include "lib/immolate.cl"

// CONFIG - This will be read from an external file
// These are default values that can be overridden
#ifndef CONFIG_ITEMS
#define CONFIG_ITEMS 8  // Number of items to search for
#define CONFIG_USE_SHOWMAN true  // Apply showman logic
#define CONFIG_MAX_ANTE 12  // Maximum ante to check
#define CONFIG_MIN_ANTE 1   // Minimum ante to check
#define CONFIG_DECK Ghost_Deck  // Deck to use
#define CONFIG_STAKE Black_Stake  // Stake to use
#endif

// Target items to search for will be read from "immolate_config.txt"
// Format of config file:
// item_name,score,flags,source,pack_type
// For example:
// Showman,10000,0,0,0
// Blueprint,5000,1,0,0
// The_Soul,2000,0,1,Spectral_Pack
// etc.

typedef struct {
    item target;         // The item to search for
    int score;           // Score for this item
    int flags;           // Special flags (0=None, 1=Must be negative, 2=Negative bonus, 3=From pack, 4=Multiple ok)
    int source;          // Source type (0=Any, 1=Specific pack)
    item pack_type;      // Pack type if source=1
} target_item;

typedef struct {
    bool itemFound[CONFIG_ITEMS];    // Tracks if each item was found
    bool itemNegative[CONFIG_ITEMS]; // Tracks if item was negative
    int itemCount[CONFIG_ITEMS];     // Count of each item (for multiple scoring)
    bool hasShowman;                 // Tracks if Showman has been found
    bool showmanNegative;            // If Showman is negative
    int totalScore;                  // Total score for this seed
    instance *inst;                  // Instance for this search
    int currentAnte;                 // Current ante being checked
    bool validSeed;                  // If this seed meets minimum requirements
} search_state;

// This will be populated from the config file
// For now, hardcode a default configuration
target_item CONFIG_TARGET_ITEMS[CONFIG_ITEMS] = {
    {Showman, 10000, 0, 0, 0},           // Item 1
    {Blueprint, 5000, 1, 0, 0},          // Item 2
    {The_Soul, 2000, 0, 1, Spectral_Pack}, // Item 3
    {Space_Joker, 1000, 0, 0, 0},        // Item 4
    {Smeared_Joker, 1000, 0, 0, 0},      // Item 5
    {Oops_All_6s, 3000, 2, 0, 0},        // Item 6
    {Voucher_Tag, 500, 0, 0, 0},         // Item 7
    {Bloodstone, 500, 4, 0, 0}           // Item 8
};

// Bonus score for negative edition (when flags = 2)
const int NEGATIVE_BONUS = 5000;

int checkItem(item foundItem, item edition, int itemIndex, search_state *state) {
    if (foundItem != CONFIG_TARGET_ITEMS[itemIndex].target) return 0;
    
    int score = 0;
    bool isNegative = (edition == Negative);
    int flags = CONFIG_TARGET_ITEMS[itemIndex].flags;
    
    // Check if we've already found this item (but not for multiple counting)
    if (state->itemFound[itemIndex] && flags != 4) return 0;
    
    // Handle Showman specially to enable its logic
    if (foundItem == Showman && !state->hasShowman) {
        state->hasShowman = true;
        state->showmanNegative = isNegative;
        state->inst->params.showman = true;
    }
    
    // Check flags
    if (flags == 1 && !isNegative) return 0;  // Must be negative
    
    // Calculate score based on flags
    if (flags == 2 && isNegative) {
        score = CONFIG_TARGET_ITEMS[itemIndex].score + NEGATIVE_BONUS;  // Bonus for negative
    } else {
        score = CONFIG_TARGET_ITEMS[itemIndex].score;
    }
    
    // Apply Showman logic if enabled
    if (CONFIG_USE_SHOWMAN && !state->hasShowman && 
        state->currentAnte > 2 && itemIndex > 0) {
        // Without Showman, only count the first instance of non-multiple items after ante 2
        if (flags != 4 && state->itemFound[itemIndex]) return 0;
    }
    
    // Mark item as found and count it
    state->itemFound[itemIndex] = true;
    if (isNegative) state->itemNegative[itemIndex] = true;
    state->itemCount[itemIndex]++;
    
    // If valid ante range is specified, check it
    if (state->currentAnte < CONFIG_MIN_ANTE ||
        state->currentAnte > CONFIG_MAX_ANTE) {
        return 0;
    }
    
    // We found a valid item, mark the seed as valid
    state->validSeed = true;
    
    return score;
}

// Rest of the implementation follows the search_template.cl pattern
// We keep this code generic and separate from the configuration
int checkTag(search_state *state) {
    item tag = next_tag(state->inst, state->currentAnte);
    
    for (int i = 0; i < CONFIG_ITEMS; i++) {
        if (CONFIG_TARGET_ITEMS[i].target == tag) {
            return checkItem(tag, No_Edition, i, state);
        }
    }
    
    return 0;
}

int checkVoucher(search_state *state) {
    item voucher = next_voucher(state->inst, state->currentAnte);
    
    for (int i = 0; i < CONFIG_ITEMS; i++) {
        if (CONFIG_TARGET_ITEMS[i].target == voucher) {
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
    
    for (int i = 0; i < CONFIG_ITEMS; i++) {
        if (CONFIG_TARGET_ITEMS[i].target == itemValue) {
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
        
        for (int i = 0; i < CONFIG_ITEMS; i++) {
            if (CONFIG_TARGET_ITEMS[i].target == joker) {
                int sourceCheck = CONFIG_TARGET_ITEMS[i].source;
                if (sourceCheck == 1 && CONFIG_TARGET_ITEMS[i].pack_type != Buffoon_Pack) continue;
                
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
            for (int i = 0; i < CONFIG_ITEMS; i++) {
                if (CONFIG_TARGET_ITEMS[i].target == The_Soul) {
                    int sourceCheck = CONFIG_TARGET_ITEMS[i].source;
                    if (sourceCheck == 1 && CONFIG_TARGET_ITEMS[i].pack_type != Spectral_Pack) continue;
                    
                    jokerdata soul = next_joker_with_info(state->inst, S_Soul, state->currentAnte);
                    score += checkItem(soul.joker, soul.edition, i, state);
                }
            }
        } else {
            // Regular spectral card
            for (int i = 0; i < CONFIG_ITEMS; i++) {
                if (CONFIG_TARGET_ITEMS[i].target == card) {
                    int sourceCheck = CONFIG_TARGET_ITEMS[i].source;
                    if (sourceCheck == 1 && CONFIG_TARGET_ITEMS[i].pack_type != Spectral_Pack) continue;
                    
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
        
        for (int i = 0; i < CONFIG_ITEMS; i++) {
            if (CONFIG_TARGET_ITEMS[i].target == card) {
                int sourceCheck = CONFIG_TARGET_ITEMS[i].source;
                if (sourceCheck == 1 && CONFIG_TARGET_ITEMS[i].pack_type != Arcana_Pack) continue;
                
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
    set_deck(inst, CONFIG_DECK);
    set_stake(inst, CONFIG_STAKE);
    init_locks(inst, 1, false, true);
    
    // Initialize the search state
    search_state state = {0};
    state.inst = inst;
    state.hasShowman = false;
    state.totalScore = 0;
    state.validSeed = false;
    
    // Reset all counters
    for (int i = 0; i < CONFIG_ITEMS; i++) {
        state.itemFound[i] = false;
        state.itemNegative[i] = false;
        state.itemCount[i] = 0;
    }
    
    // Search through each ante
    for (int ante = 1; ante <= CONFIG_MAX_ANTE; ante++) {
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