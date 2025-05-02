#include "lib/immolate.cl"

typedef struct {
    bool eternalMadnessAnte1;
    bool immolateAnte1;
    int ankhCount;
    
    // Game context
    instance* inst;
    int ante;
} game_state;

// Check if a joker is Eternal Madness
bool isEternalMadness(jokerdata joker) {
    return joker.joker == Madness && joker.stickers.eternal;
}

// Process a joker card to track Eternal Madness in ante 1
void checkJoker(jokerdata joker, game_state* state) {
    if (state->ante == 1 && isEternalMadness(joker)) {
        state->eternalMadnessAnte1 = true;
    }
}

// Process a spectral item to count Ankh cards
void checkSpectralItem(item spectral, game_state* state) {
    if (spectral == Ankh) {
        state->ankhCount++;
    } else if (spectral == Immolate && state->ante == 1) {
        state->immolateAnte1 = true;
    }
}

// Process a shop item
void processShopItem(shopitem item, game_state* state) {
    if (item.type == ItemType_Joker) {
        checkJoker(item.joker, state);
    } else if (item.type == ItemType_Spectral) {
        checkSpectralItem(item.value, state);
    }
}

// Process a pack
void processPack(pack packInfo, game_state* state) {
    // Check for Eternal Madness in buffoon packs
    if (packInfo.type == Buffoon_Pack) {
        jokerdata jokers[5];
        buffoon_pack_detailed(jokers, packInfo.size, state->inst, state->ante);
        
        for (int i = 0; i < packInfo.size; i++) {
            checkJoker(jokers[i], state);
        }
    }
    
    // Check for Ankh in spectral packs
    if (packInfo.type == Spectral_Pack) {
        item spectralCards[5];
        spectral_pack(spectralCards, packInfo.size, state->inst, state->ante);
        
        for (int i = 0; i < packInfo.size; i++) {
            checkSpectralItem(spectralCards[i], state);
        }
    }
}

long filter(instance* inst) {
    game_state state = {0};
    state.inst = inst;
    state.eternalMadnessAnte1 = false;
    state.ankhCount = 0;
    
    set_deck(inst, Ghost_Deck);
    set_stake(inst, Black_Stake);
    
    // Check all antes
    for (int ante = 1; ante <= 4; ante++) {
        state.ante = ante;
        init_unlocks(inst, ante, false);
        
        // Check shop items
        int shopItems = (ante == 1) ? 6 : 8;
        for (int i = 0; i < shopItems; i++) {
            processShopItem(next_shop_item(inst, ante), &state);
        }
        
        // Check packs
        int packCount = (ante == 1) ? 4 : 6;
        for (int p = 0; p < packCount; p++) {
            processPack(pack_info(next_pack(inst, ante)), &state);
        }
    }
    
    // Return 0 if no Eternal Madness found in ante 1, otherwise return Ankh count
    return state.eternalMadnessAnte1 && state.immolateAnte1 ? state.ankhCount : 0;
}
