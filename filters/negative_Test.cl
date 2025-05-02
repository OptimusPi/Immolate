
#define CACHE_SIZE 500
#define FIXED_FILTER_CUTOFF 1

// Searches for seeds with Observatory in ante 2 and Perkeo in ante 1 or 2
#include "lib/immolate.cl"

#define _D1 10000000
#define _D2 1000000
#define _D3 100000
#define _D4 10000
#define _D5 1000
#define _D6 100
#define _D7 10
#define _D8 1


long filter(instance* inst) {
    inst->params.showman = true;
    set_deck(inst, Ghost_Deck);
    set_stake(inst, Black_Stake);
    int oops = 0;
    int dna = 0;
    bool hasLuckyCat = false;
    int bp = 0;
    int bs = 0;
    int tb = 0;
    int trb = 0;
    bool hasShowman = false;
    int magic = 0;
    int invis = 0;
    int ecto = 0;
    bool hasCertificate = false;
    bool hasDna = false;
    

    init_locks(inst, 1, false, false);
    init_unlocks(inst, 2, false);
    if (next_voucher(inst, 2) == Telescope) {
        activate_voucher(inst, Telescope);
        if (next_voucher(inst, 3) != Observatory) return 0;
    } else return 0;

    int negTags = 0;
    for (int i = 1; i <= 14; i++) {
        if (next_tag(inst, i) == Negative_Tag)negTags++;
        if (next_tag(inst, i) == Negative_Tag)negTags++;
        next_orbital_tag(inst);
    }

    // Search for Perkeo now
    bool perkeo = false;
    int antes[15] = {1, 1, 2, 2, 2, 3, 3, 3, 4, 4, 4, 5, 5, 5};
    for (int i = 0; i < 15; i++) {
        init_unlocks(inst, antes[i], false);
        pack _pack = pack_info(next_pack(inst, antes[i]));
        item cards[10] = {RETRY, RETRY, RETRY, RETRY, RETRY, RETRY, RETRY, RETRY, RETRY, RETRY};
        cards[5] = next_shop_item(inst, antes[i]).value;
        cards[6] = next_shop_item(inst, antes[i]).value;
        cards[7] = next_shop_item(inst, antes[i]).value;
        cards[8] = next_shop_item(inst, antes[i]).value;
        cards[9] = next_shop_item(inst, antes[i]).value;
        if (_pack.type == Arcana_Pack) arcana_pack(cards, _pack.size, inst, antes[i]);
        else if (_pack.type == Spectral_Pack) spectral_pack(cards, _pack.size, inst, antes[i]);
        else if(_pack.type == Buffoon_Pack) buffoon_pack(cards, _pack.size, inst, antes[i]);
        else continue;
        for (int c = 0; c < 10; c++) {
            if (cards[c] == RETRY) continue;
            if (cards[c] == The_Soul && next_joker(inst, S_Soul, antes[i]) == Perkeo) perkeo = true;
            else if (cards[c] == Ectoplasm && c >= 5) ecto++;
            else if (cards[c] == Showman) hasShowman = true;
            else if (cards[c] == Invisible_Joker) invis++;
            else if (cards[c] == DNA) hasDna=true;
            else if (cards[c] == Certificate) hasCertificate=true;
            else if (cards[c] == Brainstorm && (hasShowman || bs < 1)) bs++;
            else if (cards[c] == Blueprint && (hasShowman || bp < 1)) bp++;
            else if (cards[c] == Turtle_Bean && (hasShowman || tb < 1)) tb++;
            else if (cards[c] == Triboulet && (hasShowman || trb < 1)) trb++;
        }
        if (i > 1 && (tb+trb < 1))
            return 0;
        // if (i > 2 && (!hasShowman && oops < 1 && bp < 1 && bp < 1 && dna < 1 && ecto < 1))
        //     return 0;
    }
    if (perkeo == false || ecto < 1 || hasCertificate == false)
        return 0;
    
    return invis*_D1 + trb*_D2 + tb*_D3 + bs*_D4 + bp*_D5 + dna*_D6 + oops*_D7 + negTags*_D8;
}