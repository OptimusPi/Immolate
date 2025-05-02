#include "lib/immolate.cl"

long filter(instance* inst) {
    set_deck(inst, Red_Deck);  // Hearts deck works well with Lusty_Joker
    set_stake(inst, Black_Stake);  // For better editions/stickers
    
    bool hasOopsAll6s = false;
    bool hasBusinessCard = false;
    bool hasLuckyCat = false;
    bool hasBloodstone = false;
    bool hasLustyJoker = false;
    int economyTagCount = 0;
    int negativeCount = 0;
    int luckJokersAnte1 = 0;
    int luckJokersAnte2 = 0;
    int luckJokerCount = 0;
    long score = 0;
    
    // Search first 5 antes
    for (int ante = 1; ante <= 5; ante++) {
        init_unlocks(inst, ante, false);
        
        // Check blind tags
        item tag1 = next_tag(inst, ante);
        item tag2 = next_tag(inst, ante);
        
        if (tag1 == Economy_Tag || tag2 == Economy_Tag) {
            economyTagCount++;
            score += 100;
        }
        
        // Skip orbital tag generation
        next_orbital_tag(inst);
        
        // Check shop items
        int shopItems = (ante == 1) ? 6 : 8;
        for (int i = 0; i < shopItems; i++) {
            shopitem item = next_shop_item(inst, ante);
            
            if (item.type == ItemType_Joker) {
                // Check for our primary jokers
                if (item.value == Oops_All_6s && !hasOopsAll6s) {
                    hasOopsAll6s = true;
                    luckJokerCount++;
                    score += 500 * (6 - ante);  // More valuable in early antes
                    
                    if (ante == 1) luckJokersAnte1++;
                    else if (ante == 2) luckJokersAnte2++;
                    
                    if (item.joker.edition == Negative || item.joker.edition == Polychrome) {
                        negativeCount++;
                        score += 300;
                    }
                }
                else if (item.value == Business_Card && !hasBusinessCard) {
                    hasBusinessCard = true;
                    score += 400 * (6 - ante);
                    
                    if (item.joker.edition == Negative || item.joker.edition == Polychrome) {
                        negativeCount++;
                        score += 300;
                    }
                }
                else if (item.value == Lucky_Cat && !hasLuckyCat) {
                    hasLuckyCat = true;
                    luckJokerCount++;
                    score += 350 * (6 - ante);
                    
                    if (ante == 1) luckJokersAnte1++;
                    else if (ante == 2) luckJokersAnte2++;
                    
                    if (item.joker.edition == Negative || item.joker.edition == Polychrome) {
                        negativeCount++;
                        score += 200;
                    }
                }
                else if (item.value == Bloodstone && !hasBloodstone) {
                    hasBloodstone = true;
                    luckJokerCount++;
                    score += 350 * (6 - ante);
                    
                    if (ante == 1) luckJokersAnte1++;
                    else if (ante == 2) luckJokersAnte2++;
                    
                    if (item.joker.edition == Negative || item.joker.edition == Polychrome) {
                        negativeCount++;
                        score += 200;
                    }
                }
                else if (item.value == Lusty_Joker && !hasLustyJoker) {
                    hasLustyJoker = true;
                    score += 300 * (6 - ante);
                    
                    if (item.joker.edition == Negative || item.joker.edition == Polychrome) {
                        negativeCount++;
                        score += 200;
                    }
                }
            }
        }
        
        // Check Buffoon packs
        pack currentPack = pack_info(next_pack(inst, ante));
        if (currentPack.type == Buffoon_Pack) {
            jokerdata packJokers[4];
            buffoon_pack_detailed(packJokers, currentPack.size, inst, ante);
            
            for (int j = 0; j < currentPack.size; j++) {
                // Check for our primary jokers in packs
                if (packJokers[j].joker == Oops_All_6s && !hasOopsAll6s) {
                    hasOopsAll6s = true;
                    luckJokerCount++;
                    score += 500 * (6 - ante);
                    
                    if (ante == 1) luckJokersAnte1++;
                    else if (ante == 2) luckJokersAnte2++;
                    
                    if (packJokers[j].edition == Negative || packJokers[j].edition == Polychrome) {
                        negativeCount++;
                        score += 300;
                    }
                }
                else if (packJokers[j].joker == Business_Card && !hasBusinessCard) {
                    hasBusinessCard = true;
                    score += 400 * (6 - ante);
                    
                    if (packJokers[j].edition == Negative || packJokers[j].edition == Polychrome) {
                        negativeCount++;
                        score += 300;
                    }
                }
                else if (packJokers[j].joker == Lucky_Cat && !hasLuckyCat) {
                    hasLuckyCat = true;
                    luckJokerCount++;
                    score += 350 * (6 - ante);
                    
                    if (ante == 1) luckJokersAnte1++;
                    else if (ante == 2) luckJokersAnte2++;
                    
                    if (packJokers[j].edition == Negative || packJokers[j].edition == Polychrome) {
                        negativeCount++;
                        score += 200;
                    }
                }
                else if (packJokers[j].joker == Bloodstone && !hasBloodstone) {
                    hasBloodstone = true;
                    luckJokerCount++;
                    score += 350 * (6 - ante);
                    
                    if (ante == 1) luckJokersAnte1++;
                    else if (ante == 2) luckJokersAnte2++;
                    
                    if (packJokers[j].edition == Negative || packJokers[j].edition == Polychrome) {
                        negativeCount++;
                        score += 200;
                    }
                }
                else if (packJokers[j].joker == Lusty_Joker && !hasLustyJoker) {
                    hasLustyJoker = true;
                    score += 300 * (6 - ante);
                    
                    if (packJokers[j].edition == Negative || packJokers[j].edition == Polychrome) {
                        negativeCount++;
                        score += 200;
                    }
                }
            }
        }
    }
    
    // Calculate final score with multipliers for combinations
    long finalScore = score;
    
    // We need at least Oops_All_6s and Business_Card
    if (!hasOopsAll6s || !hasBusinessCard) {
        return 0;
    }
    
    // Bonus for key combinations
    if (hasOopsAll6s && hasBusinessCard) finalScore *= 1.5;
    if (hasOopsAll6s && (hasLuckyCat || hasBloodstone)) finalScore *= 1.5;
    if (hasBusinessCard && (hasLuckyCat || hasBloodstone)) finalScore *= 1.5;
    if (hasLustyJoker && (hasBloodstone)) finalScore *= 1.8; // Special synergy
    
    // Bonus for early luck jokers
    if (luckJokersAnte1 >= 1) finalScore *= 2.0;
    if (luckJokersAnte2 >= 1) finalScore *= 1.5;
    
    // Bonus for higher luck joker count
    if (luckJokerCount >= 3) finalScore *= 2.0;
    
    // Bonus for economy tags
    if (economyTagCount >= 1) finalScore *= 1.5;
    
    // Bonus for negative/polychrome editions
    if (negativeCount >= 1) finalScore *= 1.5;
    if (negativeCount >= 2) finalScore *= 1.5;
    
    return finalScore;
}
