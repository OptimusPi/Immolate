// Searches for seeds with Observatory in ante 2 and Perkeo in ante 1 or 2
#define CACHE_SIZE 1000
#define FIXED_FILTER_CUTOFF 0

#include "lib/immolate.cl"

long filter(instance* inst) {
    inst->params.showman = true;
    set_deck(inst, Checkered_Deck);
    set_stake(inst, White_Stake);
    bool hasShowman = false;
    // Search for Perkeo now
    int lusty = 0;
    int bloodstone = 0;
    int oops = 0; 
    bool spaceman = false;
    bool smeared = false;
    int bp = 0;
    int bs = 0;
    int score = 0;

    int soul = 0;
    int antes[12] = {1, 1, 2, 2, 2, 3, 3, 3, 4, 4, 4};
    for (int i = 0; i < 15; i++) {
        init_unlocks(inst, antes[i], false);
        pack _pack = pack_info(next_pack(inst, antes[i]));
        item cards[7] = {RETRY, RETRY, RETRY, RETRY, RETRY, RETRY, RETRY};
        cards[5] = next_shop_item(inst, antes[i]).value;
        cards[6] = next_shop_item(inst, antes[i]).value;
        if (_pack.type == Arcana_Pack) arcana_pack(cards, _pack.size, inst, antes[i]);
        else if (_pack.type == Spectral_Pack) spectral_pack(cards, _pack.size, inst, antes[i]);
        else if(_pack.type == Buffoon_Pack) buffoon_pack(cards, _pack.size, inst, antes[i]);
        else continue;
        for (int c = 0; c < 7; c++) {
            if (cards[c] == RETRY) continue;
            else if (cards[c] == The_Soul) soul += 1;
            else if (cards[c] == The_Sun) score++;
            else if (cards[c] == Showman) hasShowman = true;
            else if (cards[c] == Space_Joker) spaceman = true;
            else if (cards[c] == Smeared_Joker) {smeared = true;}
            else if (cards[c] == Blueprint && (hasShowman || bp < 1)) bp++; 
            else if (cards[c] == Brainstorm && (hasShowman || bs < 1)) bs++; 
            else if (cards[c] == Bloodstone && (hasShowman || bloodstone == 0)) {bloodstone++;}
            else if (cards[c] == Lusty_Joker && (hasShowman || lusty == 0)) {lusty++;}
            else if (cards[c] == Oops_All_6s && (hasShowman || oops == 0)) {oops++;}
            else continue;
            if (c < 5) {
                c = 5;
            }
        }
    }

    if (!smeared) {
        return 0;
    }
                         //1410065408
    score = oops +
        bp*1000000 + 
        bs*100000 + 
        bloodstone*1000 + 
        lusty*100 + 
        score * 10 + 
        soul;

    if (spaceman) {
        score += 10000;
    }
    
    return score;
}