
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
    int immo = 0;
    int negTags = 0;

    init_locks(inst, 1, false, false);

    int observatoryAnte = 99;

    for (int i = 2; i <= 14; i++) {
        init_unlocks(inst, i, false);
        if (next_tag(inst, i) == Negative_Tag)negTags++;
        if (next_tag(inst, i) == Negative_Tag)negTags++;
        next_orbital_tag(inst);

        item nv = next_voucher(inst, i);
        activate_voucher(inst, nv);
        if (nv == Observatory) {
            activate_voucher(inst, Observatory);
            observatoryAnte = i;
        }
    }

    // Search for Perkeo now
    bool perkeo = false;
    int antes[11] = {1, 1, 2, 2, 2, 3, 3, 3, 4, 4, 4};
    for (int i = 0; i < 11; i++) {
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
            if (cards[c] == The_Soul && next_joker(inst, S_Soul, antes[i]) == Perkeo) perkeo = true;
            else if (cards[c] == The_Magician && c >= 5) magic++;
            else if (cards[c] == Showman) hasShowman = true;
            else if (cards[c] == Invisible_Joker) invis++;
            else if (cards[c] == Oops_All_6s && (hasShowman || oops < 1)) oops++;
            else if (cards[c] == DNA && (hasShowman || dna < 1)) dna++;
            else if (cards[c] == Lucky_Cat && magic > 0) hasLuckyCat=true;
            else if (cards[c] == Brainstorm && (hasShowman || bs < 1)) bs++;
            else if (cards[c] == Blueprint && (hasShowman || bp < 1)) bp++;
            else continue;
            
            if (c < 5) c = 5;
        }
    }
    if (perkeo == false || hasLuckyCat == false || oops < 1 || bp < 1 || bp < 1 || dna < 1)
        return 0;

    int antess[21] = {5, 5, 5, 6, 6, 6, 7, 7, 7, 8, 8, 8, 9, 9, 9, 10, 10, 10, 11, 11, 11};
    for (int i = 0; i < 21; i++) {
        init_unlocks(inst, antess[i], false);
        pack _pack = pack_info(next_pack(inst, antess[i]));
        item cards[10] = {RETRY, RETRY, RETRY, RETRY, RETRY, RETRY, RETRY, RETRY, RETRY, RETRY};
        cards[5] = next_shop_item(inst, antess[i]).value;
        cards[6] = next_shop_item(inst, antess[i]).value;
        cards[7] = next_shop_item(inst, antess[i]).value;
        cards[8] = next_shop_item(inst, antess[i]).value;
        cards[9] = next_shop_item(inst, antess[i]).value;
        if (_pack.type == Arcana_Pack) arcana_pack(cards, _pack.size, inst, antess[i]);
        else if (_pack.type == Spectral_Pack) spectral_pack(cards, _pack.size, inst, antess[i]);
        else if(_pack.type == Buffoon_Pack) buffoon_pack(cards, _pack.size, inst, antess[i]);
        else continue;
        for (int c = 0; c < 10; c++) {
            if (cards[c] == RETRY) continue;
            else if (cards[c] == Ectoplasm && c >= 5) ecto++;
            else if (cards[c] == Immolate && c >= 5) immo++;
            else if (cards[c] == Showman) hasShowman = true;
            else if (cards[c] == Invisible_Joker) invis++;
            else if (cards[c] == Oops_All_6s && (hasShowman || oops < 1)) oops++;
            else if (cards[c] == DNA && (hasShowman || dna < 1)) dna++;
            else if (cards[c] == Brainstorm && (hasShowman || bs < 1)) bs++;
            else if (cards[c] == Blueprint && (hasShowman || bp < 1)) bp++;
            else continue;
            if (c < 5) c = 5;
        }
    }
    return invis*_D1 + trb*_D2 + tb*_D3 + bs*_D4 + bp*_D5 + dna*_D6 + oops*_D7 + negTags*_D8;
}