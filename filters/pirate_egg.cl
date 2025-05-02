#include "lib/immolate.cl"

long filter(instance* inst) {
    set_deck(inst, Ghost_Deck);
    set_stake(inst, Black_Stake);
    
    // Tracking key jokers
    bool hasSwashbuckler = false;
    int giftCardCount = 0;
    int targetNegatives = 0;  // Count of negative Swashbuckler/Gift_Cards/Eggs/Showman
    int otherNegatives = 0;   // Count other negative jokers
    bool hasShowman = false;
    bool hasAnkhOrInvisible = false;
    int anteAllFulfilled = 99;
    int negTagCount = 0;
    
    for (int ante = 1; ante <= 6; ante++) {
        init_unlocks(inst, ante, false);
        
        // Check blind tags for Negative_Tag
        item tag1 = next_tag(inst, ante);
        item tag2 = next_tag(inst, ante);
        if (tag1 == Negative_Tag) negTagCount++;
        if (tag2 == Negative_Tag) negTagCount++;
        
        // Check shop items
        int shopItems = (ante == 1) ? 6 : 8;
        for (int i = 0; i < shopItems; i++) {
            shopitem item = next_shop_item(inst, ante);
            
            if (item.type == ItemType_Joker) {
                if (item.value == Showman) {
                    hasShowman = true;
                    if (item.joker.edition == Negative) {
                        targetNegatives++; // Count Negative Showman as target
                    }
                }
                else if (item.value == Swashbuckler && !hasSwashbuckler) {
                    hasSwashbuckler = true;
                    
                    if (item.joker.edition == Negative) {
                        targetNegatives++;
                    }
                }
                else if (item.value == Gift_Card) {
                    if (giftCardCount == 0 || hasShowman || item.joker.edition == Negative) {
                        giftCardCount++;
                        
                        if (item.joker.edition == Negative) {
                            targetNegatives++;
                        }
                    }
                }
                else if (item.value == Egg && item.joker.edition == Negative) {
                    // Count all negative eggs - they don't take up space
                    targetNegatives++;
                }
                else if (item.value == Invisible_Joker) {
                    hasAnkhOrInvisible = true;
                }
                // Count other negative jokers
                else if (item.joker.edition == Negative) {
                    otherNegatives++;
                }
            }
            else if (item.type == ItemType_Spectral && item.value == Ankh) {
                hasAnkhOrInvisible = true;
            }
        }
        
        // Check packs
        int packCount = (ante == 1) ? 4 : 6;
        for (int p = 0; p < packCount; p++) {
            pack currentPack = pack_info(next_pack(inst, ante));
            
            if (currentPack.type == Buffoon_Pack) {
                jokerdata packJokers[4];
                buffoon_pack_detailed(packJokers, currentPack.size, inst, ante);
                
                for (int j = 0; j < currentPack.size; j++) {
                    if (packJokers[j].joker == Showman) {
                        hasShowman = true;
                        if (packJokers[j].edition == Negative) {
                            targetNegatives++; // Count Negative Showman as target
                        }
                    }
                    else if (packJokers[j].joker == Swashbuckler && !hasSwashbuckler) {
                        hasSwashbuckler = true;
                        
                        if (packJokers[j].edition == Negative) {
                            targetNegatives++;
                        }
                    }
                    else if (packJokers[j].joker == Gift_Card) {
                        if (giftCardCount == 0 || hasShowman || packJokers[j].edition == Negative) {
                            giftCardCount++;
                            
                            if (packJokers[j].edition == Negative) {
                                targetNegatives++;
                            }
                        }
                    }
                    else if (packJokers[j].joker == Egg && packJokers[j].edition == Negative) {
                        // Count all negative eggs - they don't take up space
                        targetNegatives++;
                    }
                    else if (packJokers[j].joker == Invisible_Joker) {
                        hasAnkhOrInvisible = true;
                    }
                    // Count other negative jokers
                    else if (packJokers[j].edition == Negative) {
                        otherNegatives++;
                    }
                }
            }
            
            if (currentPack.type == Spectral_Pack) {
                item spectralCards[4];
                spectral_pack(spectralCards, currentPack.size, inst, ante);
                
                for (int j = 0; j < currentPack.size; j++) {
                    if (spectralCards[j] == Ankh) {
                        hasAnkhOrInvisible = true;
                        break;
                    }
                }
            }
        }
        
        // Check if we've found all required components
        if (hasSwashbuckler && giftCardCount > 0 && hasAnkhOrInvisible && anteAllFulfilled == 99) {
            anteAllFulfilled = ante;
        }
    }
    
    // Require the core components to be valid
    if (!hasSwashbuckler || giftCardCount == 0 || !hasAnkhOrInvisible) {
        return 0;
    }
    
    // Format score as [targetNegatives][negTagCount][otherNegatives][ante]
    // Cap each value at 9 to keep within one digit
    targetNegatives = targetNegatives > 9 ? 9 : targetNegatives;
    negTagCount = negTagCount > 9 ? 9 : negTagCount;
    otherNegatives = otherNegatives > 9 ? 9 : otherNegatives;
    
    return targetNegatives*1000 + negTagCount*100 + otherNegatives*10 + anteAllFulfilled;
}
