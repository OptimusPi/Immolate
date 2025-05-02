#include "lib/immolate.cl"

typedef struct {
    int target;      // The item to look for
    int score;       // Score value when found
    int flags;       // Special flags (1=must be negative, 2=must be positive, etc)
    int source;      // Where to look (0=anywhere, 1=shop, 2=pack, etc)
    int pack_type;   // If source=2, which pack type (0=any, 1=standard, 2=buffoon, etc)
    bool found;      // Whether the item has been found
    bool isNegative; // Whether the found item was negative
    int count;       // How many were found
} target_item;

typedef struct {
    bool useShowman;         // Use showman logic (multiples of same item)
    int minAnte;             // Minimum ante to search
    int maxAnte;             // Maximum ante to search
    int deckType;            // Deck type to use
    int stakeType;           // Stake type to use
    int negativeBonusScore;  // Bonus score for negative items
    int numTargets;          // Number of items in the targets array
    target_item targets[20]; // Array of target items
} filter_config;

// Global configuration - will be set by the OpenCL kernel before calling filter()
__constant filter_config CONFIG = {
    .useShowman = true,
    .minAnte = 1,
    .maxAnte = 12,
    .deckType = Ghost_Deck,
    .stakeType = Black_Stake,
    .negativeBonusScore = 5000,
    .numTargets = 0
};

bool checkTag(instance *inst, int ante, int *negativeTagCount, int *skipTagCount) {
    item tag = next_tag(inst, ante);
    if (tag == Negative_Tag) {
        (*negativeTagCount)++;
        return true;
    } else if (tag == Foil_Tag) {
        (*skipTagCount)++;
    }
    return false;
}

int scoreCard(jokerdata joker, instance *inst, bool *hasShowman) {
    int score = 0;
    
    // First check if this is the Showman joker
    if (joker.joker == Showman) {
        *hasShowman = true;
        inst->params.showman = true;
    }
    
    // Check against all target items
    for (int i = 0; i < CONFIG.numTargets; i++) {
        __constant target_item *target = &CONFIG.targets[i];
        
        // Check if the joker matches our target
        if (joker.joker == target->target) {
            // Check if we have flags for negative/positive only
            if ((target->flags & 1) && joker.edition != Negative) {
                continue;  // Skip if we need negative but it's not
            }
            if ((target->flags & 2) && joker.edition == Negative) {
                continue;  // Skip if we need positive but it's negative
            }
            
            // If we've already found this item and showman is not enabled, skip
            if (target->found && !CONFIG.useShowman && !(*hasShowman)) {
                continue;
            }
            
            // Mark as found and update stats
            target->found = true;
            target->count++;
            if (joker.edition == Negative) {
                target->isNegative = true;
                score += target->score + CONFIG.negativeBonusScore;
            } else {
                score += target->score;
            }
        }
    }
    
    return score;
}

int checkShopItems(instance *inst, int ante, bool *hasShowman) {
    int score = 0;
    int shopItems = ante * 6;  // Number of shop items scales with ante
    
    for (int i = 0; i < shopItems; i++) {
        shopitem item = next_shop_item(inst, ante);
        if (item.type == ItemType_Joker) {
            score += scoreCard(item.joker, inst, hasShowman);
        }
    }
    
    return score;
}

int checkPack(instance *inst, int ante, bool *hasShowman, pack p) {
    int score = 0;
    
    if (p.type == Buffoon_Pack) {
        jokerdata jokers[5];
        buffoon_pack_detailed(jokers, p.size, inst, ante);
        for (int i = 0; i < p.size; i++) {
            score += scoreCard(jokers[i], inst, hasShowman);
        }
    } else if (p.type == Spectral_Pack) {
        item items[5];
        spectral_pack(items, p.size, inst, ante);
        for (int i = 0; i < p.size; i++) {
            if (items[i] == The_Soul) {
                // Handle souls if needed
                jokerdata soul = next_joker_with_info(inst, S_Soul, ante);
                score += scoreCard(soul, inst, hasShowman);
            }
        }
    } else if (p.type == Arcana_Pack) {
        // Handle Arcana packs if needed
    }
    
    return score;
}

long filter(instance *inst)
{
    // Set up game parameters
    set_deck(inst, CONFIG.deckType);
    set_stake(inst, CONFIG.stakeType);
    init_locks(inst, 1, false, true);
    
    int totalScore = 0;
    bool hasShowman = false;
    int negativeTagCount = 0;
    int skipTagCount = 0;
    
    // Process each ante from min to max
    for (int ante = CONFIG.minAnte; ante <= CONFIG.maxAnte; ante++) {
        // Initialize unlocks for this ante
        init_unlocks(inst, ante, false);
        
        // Check tags (two per ante)
        checkTag(inst, ante, &negativeTagCount, &skipTagCount);
        checkTag(inst, ante, &negativeTagCount, &skipTagCount);
        
        // Check shop items
        totalScore += checkShopItems(inst, ante, &hasShowman);
        
        // Check packs (4 in ante 1, 6 in other antes)
        int numPacks = (ante == 1) ? 4 : 6;
        for (int i = 0; i < numPacks; i++) {
            pack p = pack_info(next_pack(inst, ante));
            totalScore += checkPack(inst, ante, &hasShowman, p);
        }
    }
    
    // Add bonus for negative tag and skip tag counts
    totalScore += negativeTagCount * 100;
    totalScore += skipTagCount * 50;
    
    return totalScore;
}