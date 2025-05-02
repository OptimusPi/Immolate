// Searches for a first ante with two packs that give legendary jokers
#include "lib/immolate.cl"
long filter(instance* inst) {
    set_deck(inst, Anaglyph_Deck);
    set_stake(inst, White_Stake);
    init_locks(inst, 1, false, false);

    int score = 0;
    pack _b = pack_info(next_pack(inst, 1));
    jokerdata cards1[5];
    buffoon_pack_detailed(cards1, _b.size, inst, 1);
    for (int i = 0; i < _b.size; i++) {
        if (cards1[i].joker == Blueprint || cards1[i].joker == Brainstorm) {
            score += 100;
            if (cards1[i].edition == Negative) {
                score+=110;
            }
        }
        else if (cards1[i].edition == Negative) {
            score+=1;
        }
    }
    int souls = 0;
    for (int packIndex = 1; packIndex <= 3; packIndex++) {
        pack _pack = pack_info(next_pack(inst, 1));
        item cards[5];
        if (_pack.type == Arcana_Pack) {
            arcana_pack(cards, _pack.size, inst, 1);
        } else if (_pack.type == Spectral_Pack) {
            spectral_pack(cards, _pack.size, inst, 1);
        } else continue;
        
        for (int i = 0; i < _pack.size; i++) {
            if (cards[i] == The_Soul) {
                souls ++;
            }
        }
    }
    if (souls < 2) return 0;
    return score + souls*1000;
}