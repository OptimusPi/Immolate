#include "lib/immolate.cl"

long filter(instance *inst) {
    bool c = false;
    bool p = false;
    bool t = false;
    bool o = false;
    bool l = false;
    long s = 0;
    set_deck(inst, Ghost_Deck);
    set_stake(inst, Black_Stake);
    init_locks(inst, 1, false, false);

    __attribute__((opencl_unroll_hint(2)))
    for (int ante = 1; ante <= 16; ante++) {
        init_unlocks(inst, ante, false);
        item tag = next_tag(inst, ante);
        item ap[5];
        if (tag == Charm_Tag){
            arcana_pack(ap, 5, inst, ante);
            for (int j = 0; j < 5; j++) {
                if (ap[j] == The_Soul) {
                    jokerdata jkr = next_joker_with_info(inst, S_Soul, ante);
                    if (jkr.joker == Perkeo) p = true;
                    else if (jkr.joker == Canio) c = true;
                    else if (jkr.joker == Triboulet) l = true;
                    else break;
                    if (jkr.edition == Negative) s += 10000;
            }}}
        item tag2 = next_tag(inst, ante);
        if (tag2 == Charm_Tag) {
            arcana_pack(ap, 5, inst, ante);
            for (int j = 0; j < 5; j++) {
                if (ap[j] == The_Soul) {
                    jokerdata jkr = next_joker_with_info(inst, S_Soul, ante);
                    if (jkr.joker == Perkeo) p = true;
                    else if (jkr.joker == Canio) c = true;
                    else if (jkr.joker == Triboulet) l = true;
                    else break;
                    if (jkr.edition == Negative) s += 10000;
        }}}
        if (tag == Negative_Tag) s += 100;
        if (tag2 == Negative_Tag) s += 10;
        if (tag == Double_Tag) s += 1;
        if (tag2 == Double_Tag) s += 1;
        if (!t && next_voucher(inst, ante) == Telescope) { t = true; activate_voucher(inst, Telescope); }
        if (t && next_voucher(inst, ante+1) == Observatory) { o = true; }
        if (ante == 2 && (p == false)) return 0;
        if (ante == 8 && (c == false || o == false)) return 0;
    }
    return s;
}