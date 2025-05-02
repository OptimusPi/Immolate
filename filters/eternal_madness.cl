#include "lib/immolate.cl"

long filter(instance* inst) {
    // Set up basic game parameters
    set_deck(inst, Ghost_Deck);
    set_stake(inst, Black_Stake);
    init_locks(inst, 1, false, false);
    
    // Track scores and required jokers
    int score = 0;
    bool hasEternalMadness = false;
    int ankhCount = 0;
    
    // Check ante 1 for eternal Madness - only check first 6 shop items
    for (int i = 0; i < 6; i++) {
        shopitem item = next_shop_item(inst, 1);
        if (item.type == ItemType_Joker) {
            if (item.joker.joker == Madness && item.joker.stickers.eternal) {
                hasEternalMadness = true;
            } else if (item.joker.stickers.eternal) {
                // 1 point for other eternals
                score += 1;
            }
        } else if (item.type == ItemType_Spectral && item.value == Ankh) {
            ankhCount++;
        }
    }
    
    // Check ante 1 packs - typically 4 packs in ante 1
    for (int i = 0; i < 4; i++) {
        pack p = pack_info(next_pack(inst, 1));
        if (p.type == Buffoon_Pack) {
            jokerdata jokers[5];
            buffoon_pack_detailed(jokers, p.size, inst, 1);