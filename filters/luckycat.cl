#include "lib/immolate.cl"
#define CACHE_SIZE 2000

long getScore(jokerdata joker, instance* inst, int ante, int* negatives, int* lucky_cat, int* bp, int* oops, int * show, int * dna) {
    long score = 0;
    if (joker.joker == RETRY) return 0;
    if (joker.edition == Negative) {
        (*negatives)++;
        score += 10;
        if (ante > 3)
            score += 1;
        if (joker.joker == Blueprint) {score += 100;}
        else if (joker.joker == Brainstorm) {score += 100;}
        else { score += 4;}
    
    }
    if (joker.edition == Polychrome)
        score++;

    if (joker.joker == Oops_All_6s) { 
        if (*oops > 0) {
            if (*show > 0) {
                (*oops)++;
                score += 100;
            } else {
                score += 2;
            }
        } else {
            (*oops)++; 
        }
        if (joker.edition == Negative) {
            score += 1000;
        }
        if (joker.stickers.eternal) {
            if (ante == 1)
                score += 500;
            score += 5;
        }
        score += 1;
    }
    else if (joker.joker == Showman) { 
        (*show)++; 
        score += ante < 2 ? 250 : 8;
        inst->params.showman = true; // Set showman parameter to true
    }
    else if (joker.joker == Lucky_Cat) {
        if (ante > 1) {
            (*lucky_cat)++; 
            score += ante < 4 ? 500 : 6;
        }
    }
    else if (joker.joker == Blueprint || joker.joker == Brainstorm) {
        (*bp)++; 
        score += ante < 2 ? 1000 : 10;
    }
    else if (joker.joker == Invisible_Joker ) { score += 500;}
    else if (joker.joker == Space_Joker || joker.joker == Burnt_Joker) { score += 777;}
    else if (joker.joker == DNA ) { (*dna)++; score += 600;}
    else if (joker.stickers.eternal) {
        score += 1;
        if (joker.edition == Negative) {
            score += 1111;
        }
        else if (joker.edition == Polychrome) {
            score += 100;
        }
    }

    return score;
}

long check_next_pack(instance* inst, int ante, int * negatives, int * lucky_cat, int * bp, int * oops, int * show, int * dna) {
    pack pack = pack_info(next_pack(inst, ante));

    if (pack.type != Buffoon_Pack) {
        if (pack.type == Spectral_Pack) {
            item cards[5];
            spectral_pack(cards, pack.size, inst, ante);
            for (int index = 0; index < pack.size; index++) {
                if (cards[index] == Ankh)
                    return ante == 1 ? 1000 : 2;
                if (cards[index] == Ectoplasm)
                     return 100;
                if (cards[index] == The_Soul)
                     return 1000;
            }
            return 0; 
        }

        return 0;
    }

    // Generate next x jokers that will be in the pack
    jokerdata jokers[4];
    buffoon_pack_detailed(jokers, pack.size, inst, ante);

    int score = 0;
    for (int index = 0; index < pack.size; index++) {
        int nextCardScore = getScore(jokers[index], inst, ante, negatives, lucky_cat, bp, oops, show, dna);
        if (nextCardScore > score) {
            score = nextCardScore;
        }
    }

    return score;
}

bool check_next_shopitem(instance* inst, int ante, int* negatives, int* lucky_cat, int *bp, int * oops, int * show, int * dna) {

    shopitem shopItem = next_shop_item(inst, ante);

    if (shopItem.type == ItemType_Joker) {
        return getScore(shopItem.joker, inst, ante, negatives, lucky_cat, bp, oops, show, dna);
    } 
    
    if (shopItem.type == ItemType_Spectral) {
        if (shopItem.value == Immolate) {
            if (ante < 3)
                return 24;
            else
                return 2;
        }
        if (shopItem.value == Ankh) {
            return ante > 1 ? 69 : 1; 
        }
        if (shopItem.value == Ectoplasm) {
            return ante == 1? 2 : 6;
        }
        if (shopItem.value == The_Soul)
            return ante * 3;
    }
    return 0;
}

// In which pack ante 1 you get soul (if all packs are opened one after another from left to right)
int get_soul_index(instance* inst, int ante) {
    for (int packIndex = 1; packIndex <= 4; packIndex++) {
        pack pack = pack_info(next_pack(inst, ante));
        item cards[5];
        
        if (pack.type == Arcana_Pack) {
            arcana_pack(cards, pack.size, inst, ante);
        } else if (pack.type == Spectral_Pack) {
            spectral_pack(cards, pack.size, inst, ante);
        } else {
            continue;
        }
        
        for (int i = 0; i < pack.size; i++) {
            if (cards[i] == The_Soul) {
                return packIndex;
            }
        }
    }

    return -1;
}

long filter(instance* inst) {
    set_deck(inst, Ghost_Deck);
    set_stake(inst, Black_Stake);
    init_locks(inst, 1, false, false);

    int ante = 1;
    item jokerFromSoul = next_joker(inst, S_Soul, ante);
    if (jokerFromSoul == Perkeo) {
        int soulPackIndex = get_soul_index(inst, ante);
        if (soulPackIndex <= 0) {
            return 0;
        }
    } else {
        jokerFromSoul = next_joker(inst, S_Soul, ante+1);
        if (jokerFromSoul != Perkeo) 
            return 0;
        int soulPackIndex = get_soul_index(inst, ante+1);
        if (soulPackIndex <= 0) {
            return 0;
        }
    }

    long score = 0;
    int lucky_cat = 0;
    int negatives = 0;
    int bp = 0;
    int show = 0;
    int oops = 0;
    int dna = 0;
    score += check_next_shopitem(inst, 1, &negatives, &lucky_cat, &bp, &oops, &show, &dna);
    score += check_next_shopitem(inst, 1, &negatives, &lucky_cat, &bp, &oops, &show, &dna);
    score += check_next_pack(inst, 1, &negatives, &lucky_cat, &bp, &oops, &show, &dna);
    score += check_next_pack(inst, 1, &negatives, &lucky_cat, &bp, &oops, &show, &dna);
    score += check_next_shopitem(inst, 1, &negatives, &lucky_cat, &bp, &oops, &show, &dna);
    score += check_next_shopitem(inst, 1, &negatives, &lucky_cat, &bp, &oops, &show, &dna);
    score += check_next_shopitem(inst, 1, &negatives, &lucky_cat, &bp, &oops, &show, &dna);
    score += check_next_shopitem(inst, 1, &negatives, &lucky_cat, &bp, &oops, &show, &dna);
    score += check_next_pack(inst, 1, &negatives, &lucky_cat, &bp, &oops, &show, &dna);
    score += check_next_pack(inst, 1, &negatives, &lucky_cat, &bp, &oops, &show, &dna);  
    if (oops > 0)
        score += 20;
    
    if (negatives > 0)
        score += 10;
    
    if (bp > 0)
        score += 10;
    
    if (show > 0)
        score += 20;
    for ( int ante = 2; ante <= 4 ; ante++) {
        for (int i = 0; i < 3; i++) {
            score += check_next_shopitem(inst, ante, &negatives, &lucky_cat, &bp, &oops, &show, &dna);
            score += check_next_shopitem(inst, ante, &negatives, &lucky_cat, &bp, &oops, &show, &dna);
            score += check_next_shopitem(inst, ante, &negatives, &lucky_cat, &bp, &oops, &show, &dna);
            score += check_next_shopitem(inst, ante, &negatives, &lucky_cat, &bp, &oops, &show, &dna);
            score += check_next_pack(inst, ante, &negatives, &lucky_cat, &bp, &oops, &show, &dna);
            score += check_next_pack(inst, ante, &negatives, &lucky_cat, &bp, &oops, &show, &dna);
        }
    }
    if (oops < 2 || bp == 0) return 0;

    for ( int ante = 5; ante <= 14; ante++) {
        for (int i = 0; i < 6; i++) {
            score += check_next_shopitem(inst, ante, &negatives, &lucky_cat, &bp, &oops, &show, &dna);
            score += check_next_shopitem(inst, ante, &negatives, &lucky_cat, &bp, &oops, &show, &dna);
            score += check_next_shopitem(inst, ante, &negatives, &lucky_cat, &bp, &oops, &show, &dna);
            score += check_next_shopitem(inst, ante, &negatives, &lucky_cat, &bp, &oops, &show, &dna);
            score += check_next_shopitem(inst, ante, &negatives, &lucky_cat, &bp, &oops, &show, &dna);
            score += check_next_shopitem(inst, ante, &negatives, &lucky_cat, &bp, &oops, &show, &dna);
            score += check_next_shopitem(inst, ante, &negatives, &lucky_cat, &bp, &oops, &show, &dna);
            score += check_next_shopitem(inst, ante, &negatives, &lucky_cat, &bp, &oops, &show, &dna);

            score += check_next_pack(inst, ante, &negatives, &lucky_cat, &bp, &oops, &show, &dna);
            if (lucky_cat == 0 || bp < 1) return 0;
        }
    }
    
    
    return score;
}
