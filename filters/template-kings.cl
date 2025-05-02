
// Searches for seeds with Observatory in ante 2 and Perkeo in ante 1 or 2
#include "lib/immolate.cl"

#define _D1  100000000
#define _D2  10000000
#define _D3  1000000
#define _D4  100000
#define _D5  10000
#define _D6  1000
#define _D7  100
#define _D8  10

long filter(instance* inst) {
    /// BEGIN CONFIG
    #define NUM_NEEDS 2
    #define NUM_WANTS 8
    #define NEED_BY_ANTE 4
    #define WANT_BY_ANTE 8
    item Needs[NUM_NEEDS] = { Canio, Perkeo };
    item Wants[NUM_WANTS] = {
        Sock_and_Buskin,    DNA,
        Blueprint,          Brainstorm,
        Oops_All_6s,        Invisible_Joker,
        Trading_Card,       Space_Joker
    };
    bool ScoreNeeds[2] = { false, false };
    int ScoreWants[8] = { 0, 0, 0, 0, 0, 0, 0, 0 };
    set_deck(inst, Ghost_Deck);
    set_stake(inst, Black_Stake);
    inst->params.showman = true;
    init_locks(inst, 1, false, false);
    // END CONFIG

    /// BEGIN OBSERVATORY & NEGATIVE TAGS SEARCH
    int ScoreDigits[8] = { _D1, _D2, _D3, _D4, _D5, _D6, _D7, _D8 };
    int observatoryAnte = 99;
    int negTags = 0;
    for (int i = 1; i <= 8; i++) {
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
    if (observatoryAnte == 99) {
        return 0;
    }
    // END OBSERVATORY / NEGATIVE TAGS SEARCH

    // SEARCH FOR NEEDS
    int negJokers = 0;
    for (int ante = 1; ante <= WANT_BY_ANTE; ante++) {
        init_unlocks(inst, ante, false);
        item cards[36] = {  
            RETRY, RETRY, RETRY, RETRY,     RETRY, RETRY, RETRY, RETRY,
            RETRY, RETRY, RETRY, RETRY,     RETRY, RETRY, RETRY, RETRY,
        };
        int cardsIndex = 0;
        cards[30] = next_shop_item(inst, ante).value;
        cards[31] = next_shop_item(inst, ante).value;
        cards[32] = next_shop_item(inst, ante).value;
        cards[33] = next_shop_item(inst, ante).value;
        if (ante > 1) {
            cards[34] = next_shop_item(inst, ante).value;
            cards[35] = next_shop_item(inst, ante).value;
        }
        for (int p = 0; p < 6; p++) {
            if (ante == 1 && p >= 4) continue;
            item cardsTemp[5] = { RETRY, RETRY, RETRY, RETRY, RETRY };
            pack _pack = pack_info(next_pack(inst, ante));
            if (_pack.type == Arcana_Pack) arcana_pack(cardsTemp, _pack.size, inst, ante);
            else if (_pack.type == Spectral_Pack) spectral_pack(cardsTemp, _pack.size, inst, ante);
            else if(_pack.type == Buffoon_Pack) buffoon_pack(cardsTemp, _pack.size, inst, ante);
            else continue;
            for (int t = 0; t < 5; t++) {
                cards[cardsIndex++] = cardsTemp[t];
            }
        }
        for (int c = 0; c < 36; c++) {
            item jkr = RETRY;
            if (cards[c] == RETRY) continue;
            else if (cards[c] == The_Soul){
                jkr = next_joker(inst, S_Soul, ante);
            }
            for (int x = 0; x < NUM_NEEDS; x++) {
                if (jkr == Needs[x]) ScoreNeeds[x] = true;
            }
            for (int x = 0; x < NUM_WANTS; x++) {
                if (jkr == Wants[x]) ScoreWants[x]++;
            }
        }
        if (ante == NEED_BY_ANTE) {
            for (int n = 0; n < NUM_NEEDS; n++)
                if (ScoreNeeds[n] == false) return 0;
        }
    }

    long score = 0;
    for (int w = 0; w < NUM_WANTS; w++) {
        score += ScoreWants[w] * ScoreDigits[w];
    }
    score += negTags * _D8;
    score += negJokers;
    return score;
}