// Searches for an Erratic Deck seed with lots of a rank
#include "lib/immolate.cl"

long filter(instance* inst) {
    set_deck(inst, Anaglyph_Deck);
    set_stake(inst, White_Stake);
    init_locks(inst, 1, false, true);
    bool hasShowman = false;    
    long blueprints = 0;
    long brainstorms = 0;
    long invisible = 0;
    long score = 0;
    for (int ante = 1; ante < 3; ante++) {
        next_voucher(inst, ante);
        init_unlocks(inst, ante, false);
        if (next_tag(inst, ante) == Negative_Tag) {
            score += 10;
        }
        next_orbital_tag(inst);
        if (next_tag(inst, ante) == Negative_Tag) {
            score += 1;
        }
        next_orbital_tag(inst);
        next_orbital_tag(inst);

        int checks = ante == 1 ? 4 : 6;
        for (int check = 0; check < checks; check++) {
            shopitem sItem = next_shop_item(inst, ante);
            if (sItem.value == Showman) {
                hasShowman = true;
                inst->params.showman = true;
            }
            else if (sItem.value == Blueprint) {
                if (blueprints == 0 || hasShowman) {
                    blueprints++;
                    if (sItem.joker.edition == Negative) {
                        score += 1000;
                    }
                }
            } else if (sItem.value == Brainstorm) {
                if (brainstorms == 0 || hasShowman) {
                    brainstorms++;
                    if (sItem.joker.edition == Negative) {
                        score += 1000;
                    }
                }
            }
            else if (sItem.value == Invisible_Joker) {
                 if (invisible == 0 || hasShowman) {
                    invisible++;
                }
            } else {
                if (sItem.joker.edition == Negative) {
                    score += 100;
                }
            }
        }
    }

  return score;
}