#include "lib/immolate.cl"

long filter(instance* inst) {
    set_deck(inst, Blue_Deck);  // Blue deck for better defense
    set_stake(inst, Black_Stake);  // Higher difficulty = better jokers
    
    // Health strategy key jokers
    bool hasVampire = false;
    bool hasAncientJoker = false;
    bool hasCastle = false;
    bool hasAcrobat = false;
    bool hasGoldCard = false;  // Gold Card enhancement for additional health
    
    // Important tags for health strategy
    bool hasEtherealTag = false;
    bool hasMeteorite = false;  // For maximize health gain
    
    // Enhancement tracking
    int healthJokerCount = 0;
    int negativesFound = 0;
    int earlyHealthJokers = 0;
    long score = 0;
    
    // Check first 5 antes (most critical for establishing build)
    for (int ante = 1; ante <= 5; ante++) {
        init_unlocks(inst, ante, false);
        
        // Check blind tags
        item tag1 = next_tag(inst, ante);
        item tag2 = next_tag(inst, ante);
        
        if (tag1 == Ethereal_Tag || tag2 == Ethereal_Tag) {
            hasEtherealTag = true;
            score += 200;
        }
        
        if (tag1 == Meteor_Tag || tag2 == Meteor_Tag) {
            hasMeteorite = true;
            score += 200;
        }
        
        // Get orbital tag result but don't need to store it
        next_orbital_tag(inst);
        
        // Check shop items for health-related jokers
        int shopItems = (ante == 1) ? 6 : 8;
        for (int i = 0; i < shopItems; i++) {
            shopitem item = next_shop_item(inst, ante);
            
            if (item.type == ItemType_Joker) {
                // Check for our key jokers
                if (item.value == Vampire && !hasVampire) {
                    hasVampire = true;
                    healthJokerCount++;
                    score += 600 * (6 - ante);  // Very valuable early
                    
                    if (ante <= 2) earlyHealthJokers++;
                    
                    if (item.joker.edition == Negative) {
                        negativesFound++;
                        score += 500;  // Negative Vampire is extremely valuable
                    } else if (item.joker.edition == Polychrome) {
                        score += 250;  // Polychrome also good
                    }
                }
                else if (item.value == Ancient_Joker && !hasAncientJoker) {
                    hasAncientJoker = true;
                    healthJokerCount++;
                    score += 500 * (6 - ante);
                    
                    if (ante <= 2) earlyHealthJokers++;
                    
                    if (item.joker.edition == Negative) {
                        negativesFound++;
                        score += 400;
                    } else if (item.joker.edition == Polychrome) {
                        score += 200;
                    }
                }
                else if (item.value == Castle && !hasCastle) {
                    hasCastle = true;
                    healthJokerCount++;
                    score += 400 * (6 - ante);
                    
                    if (ante <= 2) earlyHealthJokers++;
                    
                    if (item.joker.edition == Negative) {
                        negativesFound++;
                        score += 300;
                    } else if (item.joker.edition == Polychrome) {
                        score += 150;
                    }
                }
                else if (item.value == Acrobat && !hasAcrobat) {
                    hasAcrobat = true;
                    healthJokerCount++;
                    score += 400 * (6 - ante);
                    
                    if (ante <= 2) earlyHealthJokers++;
                    
                    if (item.joker.edition == Negative) {
                        negativesFound++;
                        score += 300;
                    } else if (item.joker.edition == Polychrome) {
                        score += 150;
                    }
                }
                // Check for any Negative editions
                else if (item.joker.edition == Negative) {
                    negativesFound++;
                    score += 50;
                }
            }
            // Check for Gold Card enhancement in standard pack for additional health
            else if (item.type == ItemType_PlayingCard) {
                card stdCard = standard_card(inst, ante);
                if (stdCard.enhancement == Gold_Card) {
                    hasGoldCard = true;
                    score += 100;
                }
            }
        }
        
        // Check Buffoon packs for our key jokers
        pack currentPack = pack_info(next_pack(inst, ante));
        if (currentPack.type == Buffoon_Pack) {
            jokerdata packJokers[4];
            buffoon_pack_detailed(packJokers, currentPack.size, inst, ante);
            
            for (int j = 0; j < currentPack.size; j++) {
                if (packJokers[j].joker == Vampire && !hasVampire) {
                    hasVampire = true;
                    healthJokerCount++;
                    score += 600 * (6 - ante);
                    
                    if (ante <= 2) earlyHealthJokers++;
                    
                    if (packJokers[j].edition == Negative) {
                        negativesFound++;
                        score += 500;
                    } else if (packJokers[j].edition == Polychrome) {
                        score += 250;
                    }
                }
                else if (packJokers[j].joker == Ancient_Joker && !hasAncientJoker) {
                    hasAncientJoker = true;
                    healthJokerCount++;
                    score += 500 * (6 - ante);
                    
                    if (ante <= 2) earlyHealthJokers++;
                    
                    if (packJokers[j].edition == Negative) {
                        negativesFound++;
                        score += 400;
                    } else if (packJokers[j].edition == Polychrome) {
                        score += 200;
                    }
                }
                else if (packJokers[j].joker == Castle && !hasCastle) {
                    hasCastle = true;
                    healthJokerCount++;
                    score += 400 * (6 - ante);
                    
                    if (ante <= 2) earlyHealthJokers++;
                    
                    if (packJokers[j].edition == Negative) {
                        negativesFound++;
                        score += 300;
                    } else if (packJokers[j].edition == Polychrome) {
                        score += 150;
                    }
                }
                else if (packJokers[j].joker == Acrobat && !hasAcrobat) {
                    hasAcrobat = true;
                    healthJokerCount++;
                    score += 400 * (6 - ante);
                    
                    if (ante <= 2) earlyHealthJokers++;
                    
                    if (packJokers[j].edition == Negative) {
                        negativesFound++;
                        score += 300;
                    } else if (packJokers[j].edition == Polychrome) {
                        score += 150;
                    }
                }
                // Check for any Negative editions
                else if (packJokers[j].edition == Negative) {
                    negativesFound++;
                    score += 50;
                }
            }
        }
        
        // Check Standard packs for Gold Card enhancement
        if (currentPack.type == Standard_Pack) {
            card stdCards[5];
            standard_pack(stdCards, currentPack.size, inst, ante);
            
            for (int j = 0; j < currentPack.size; j++) {
                if (stdCards[j].enhancement == Gold_Card) {
                    hasGoldCard = true;
                    score += 100;
                }
            }
        }
    }
    
    // Calculate final score with multipliers for combinations
    long finalScore = score;
    
    // Must have Vampire to be a valid seed for this strategy
    if (!hasVampire) {
        return 0;
    }
    
    // Bonus for key combinations
    if (hasVampire && hasAncientJoker) finalScore *= 2.0;
    if (hasVampire && hasAcrobat) finalScore *= 1.5;
    if (hasVampire && hasCastle) finalScore *= 1.5;
    
    // The full health combo
    if (hasVampire && hasAncientJoker && hasAcrobat && hasCastle) finalScore *= 3.0;
    
    // Bonus for beneficial tags
    if (hasEtherealTag) finalScore *= 1.3;
    if (hasMeteorite) finalScore *= 1.3;
    
    // Bonus for early health jokers
    if (earlyHealthJokers >= 2) finalScore *= 2.0;
    
    // Bonus for health joker count
    if (healthJokerCount >= 3) finalScore *= 1.5;
    
    // Bonus for negative editions
    if (negativesFound >= 1) finalScore *= 1.2;
    if (negativesFound >= 2) finalScore *= 1.3;
    
    // Bonus for gold card enhancement
    if (hasGoldCard) finalScore *= 1.2;
    
    return finalScore;
}
