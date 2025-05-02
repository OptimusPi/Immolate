// Searches for seeds with Observatory in ante 2 and Perkeo in ante 1 or 2
#include "lib/immolate.cl"

long filter(instance* inst) {
    inst->params.showman = true;
    set_deck(inst, Red_Deck);
    set_stake(inst, White_Stake);
    bool hasShowman = false;
    // Search for Perkeo now
    bool bloodstone = false;
    bool spade = false; 
    bool diamond = false;
    bool club = false;
    int score = 0;

    int antes[5] = {1, 1, 2, 2, 2};
    for (int i = 0; i < 5; i++) {
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
            else if (cards[c] == The_Soul) score++;
            else if (cards[c] == Showman) hasShowman = true;
            else if (cards[c] == Bloodstone && (hasShowman || hearts == 0)) {heart++;}
            else if (cards[c] == Greedy_Joker && (hasShowman || Smeared_Joker == 0)) {smeared = true;}
            else if (cards[c] == Wrathful_Joker && (hasShowman || spade == 0)) {spade++;}
            else if (cards[c] == Gluttonous_Joker && (hasShowman || club == 0)) {club++;}
            else continue;
            if (c < 5) {
                break;
            }
        }
    }
    
    return heart * 10000 + diamond * 1000 + spade * 100 + club * 10 + score;
}