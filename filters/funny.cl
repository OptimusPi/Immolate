#include "lib/immolate.cl"

long filter(instance* inst) {
    // Configuration
    set_deck(inst, Ghost_Deck);  // Ghost deck for spectrals
    set_stake(inst, Black_Stake); // High difficulty for Eternal/Polychrome chance

    // Initialize tracking variables for hand size strategy
    long score = 0;
    int turtleBeanCount = 0;
    int troubadourCount = 0;
    int juggleTagCount = 0;
    bool hasEternalTurtleBean = false;
    bool hasEternalTroubadour = false;
    bool hasNegativeTurtleBean = false;
    bool hasNegativeTroubadour = false;
    bool hasShowman = false;
    int showmanAnte = 99;  // Track when Showman appears
    int handSizeJokers = 0;
    int ante1HandSizeJokers = 0;
    int ante2HandSizeJokers = 0;

    // Check early antes for hand size components
    for (int ante = 1; ante <= 5; ante++) {
        init_unlocks(inst, ante, false);
        
        // Check blind tags for Juggle_Tag
        item tag1 = next_tag(inst, ante);
        item tag2 = next_tag(inst, ante);
        
        if (tag1 == Juggle_Tag || tag2 == Juggle_Tag) {
            juggleTagCount++;
            score += 300 * (6 - ante); // More valuable in earlier antes
        }
        
        // Check shop items
        int shopItems = (ante == 1) ? 6 : 8;
        for (int i = 0; i < shopItems; i++) {
            shopitem item = next_shop_item(inst, ante);
            
            // Check for Showman first (important for duplicate jokers)
            if (item.type == ItemType_Joker && item.value == Showman && !hasShowman) {
                hasShowman = true;
                showmanAnte = ante;
                score += 400 * (6 - ante); // Very valuable in early antes
            }
            // Check for hand size jokers
            else if (item.type == ItemType_Joker) {
                if (item.value == Turtle_Bean) {
                    // Only count additional copies if we have Showman or it's negative edition
                    if (turtleBeanCount == 0 || hasShowman || item.joker.edition == Negative) {
                        turtleBeanCount++;
                        handSizeJokers++;
                        if (ante == 1) ante1HandSizeJokers++;
                        if (ante == 2) ante2HandSizeJokers++;
                        
                        // Base points for finding a Turtle_Bean
                        score += 300 * (6 - ante); // More valuable in earlier antes
                        
                        // Check for special editions/stickers
                        if (item.joker.stickers.eternal) {
                            hasEternalTurtleBean = true;
                            score += 300;
                        }
                        if (item.joker.edition == Negative) {
                            hasNegativeTurtleBean = true;
                            score += 400;
                        } else if (item.joker.edition == Polychrome) {
                            score += 150;
                        }
                    }
                } 
                else if (item.value == Troubadour) {
                    // Only count additional copies if we have Showman or it's negative edition
                    if (troubadourCount == 0 || hasShowman || item.joker.edition == Negative) {
                        troubadourCount++;
                        handSizeJokers++;
                        if (ante == 1) ante1HandSizeJokers++;
                        if (ante == 2) ante2HandSizeJokers++;
                        
                        // Base points for finding a Troubadour
                        score += 300 * (6 - ante); // More valuable in earlier antes
                        
                        // Check for special editions/stickers
                        if (item.joker.stickers.eternal) {
                            hasEternalTroubadour = true;
                            score += 300;
                        }
                        if (item.joker.edition == Negative) {
                            hasNegativeTroubadour = true;
                            score += 400;
                        } else if (item.joker.edition == Polychrome) {
                            score += 150;
                        }
                    }
                }
            }
        }
        
        // Check Buffoon packs for our target jokers
        pack currentPack = pack_info(next_pack(inst, ante));
        if (currentPack.type == Buffoon_Pack) {
            jokerdata packJokers[4];
            buffoon_pack_detailed(packJokers, currentPack.size, inst, ante);
            
            // First check for Showman in the pack
            for (int j = 0; j < currentPack.size; j++) {
                if (packJokers[j].joker == Showman && !hasShowman) {
                    hasShowman = true;
                    showmanAnte = ante;
                    inst->params.showman = true;
                    score += 400 * (6 - ante); // Very valuable in early antes
                    break;
                }
            }
            
            // Then check for our target jokers
            for (int j = 0; j < currentPack.size; j++) {
                if (packJokers[j].joker == Turtle_Bean) {
                    // Only count additional copies if we have Showman or it's negative edition
                    if (turtleBeanCount == 0 || hasShowman || packJokers[j].edition == Negative) {
                        turtleBeanCount++;
                        handSizeJokers++;
                        if (ante == 1) ante1HandSizeJokers++;
                        if (ante == 2) ante2HandSizeJokers++;
                        
                        score += 300 * (6 - ante);
                        
                        if (packJokers[j].stickers.eternal) {
                            hasEternalTurtleBean = true;
                            score += 300;
                        }
                        if (packJokers[j].edition == Negative) {
                            hasNegativeTurtleBean = true;
                            score += 400;
                        } else if (packJokers[j].edition == Polychrome) {
                            score += 150;
                        }
                    }
                }
                else if (packJokers[j].joker == Troubadour) {
                    // Only count additional copies if we have Showman or it's negative edition
                    if (troubadourCount == 0 || hasShowman || packJokers[j].edition == Negative) {
                        troubadourCount++;
                        handSizeJokers++;
                        if (ante == 1) ante1HandSizeJokers++;
                        if (ante == 2) ante2HandSizeJokers++;
                        
                        score += 300 * (6 - ante);
                        
                        if (packJokers[j].stickers.eternal) {
                            hasEternalTroubadour = true;
                            score += 300;
                        }
                        if (packJokers[j].edition == Negative) {
                            hasNegativeTroubadour = true;
                            score += 400;
                        } else if (packJokers[j].edition == Polychrome) {
                            score += 150;
                        }
                    }
                }
            }
        }
    }
    
    // Calculate final score with multipliers for combinations
    long finalScore = score;
    
    // Bonus for finding both key jokers
    if (turtleBeanCount > 0 && troubadourCount > 0) {
        finalScore *= 2;
    }
    
    // Bonus for finding juggle tag with hand size jokers
    if (juggleTagCount > 0 && handSizeJokers > 0) {
        finalScore *= 1.5;
    }
    
    // Bonus for finding multiple of each joker (requires Showman or Negative editions)
    if (turtleBeanCount >= 2) finalScore *= 1.5;
    if (troubadourCount >= 2) finalScore *= 1.5;
    
    // Bonus for finding jokers very early (ante 1-2)
    if (ante1HandSizeJokers >= 1) finalScore *= 2;
    if (ante2HandSizeJokers >= 1) finalScore *= 1.5;
    
    // Bonus for special editions/stickers
    if (hasEternalTurtleBean || hasEternalTroubadour) finalScore *= 1.5;
    if (hasNegativeTurtleBean || hasNegativeTroubadour) finalScore *= 2;
    
    
    // Require at least one of our target jokers for the seed to be considered
    if (turtleBeanCount + troubadourCount == 0) {
        return 0;
    }
    
    return finalScore;
}
