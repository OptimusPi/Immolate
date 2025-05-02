// Searches for an Erratic Deck seed with lots of a rank
#include "lib/immolate.cl"
#define FIXED_FILTER_CUTOFF

long scoreCard(instance *inst, jokerdata joker, int * hack, int * wee, int * blueprint) {
    if (joker.joker == Sock_and_Buskin ||
            joker.joker == Hanging_Chad ||
            joker.joker == Blueprint ||
            joker.joker == Brainstorm ||
            joker.joker == Bloodstone ||
            joker.joker == Space_Joker ||
            joker.joker == Hack ||
            joker.joker == Lucky_Cat ||
            joker.joker == Pareidolia ||
            joker.joker == Business_Card ||
            joker.joker == Blueprint ||
            joker.joker == Brainstorm ||
            joker.joker == Oops_All_6s ||
            joker.joker == Invisible_Joker ||
            joker.joker == Wee_Joker ||
            joker.joker == Burnt_Joker ||
            joker.joker == Showman)
    {
        if (joker.joker == Showman) inst->params.showman = true;
        if (joker.joker == Hack) *hack += 1;
        if (joker.joker == Wee_Joker) *wee += 1;
        if (joker.joker == Blueprint || joker.joker == Brainstorm) *blueprint += 1;

        // negative desired jokers
         return joker.edition == Negative ? 1000 : 100;
    }

    // regular stupid jokers
    return joker.edition == Negative ? 1 : 0;
}

long check_next_pack(instance* inst, int ante, int * hack, int * wee, bool * perkeo, int * blueprint) {
    pack pack = pack_info(next_pack(inst, ante));

    if (pack.type != Buffoon_Pack) {
        int score = 0;
        item cards[5] = { RETRY, RETRY, RETRY, RETRY, RETRY };
        if (pack.type == Arcana_Pack) {
            arcana_pack(cards, pack.size, inst, ante);
        }
        else if (pack.type == Spectral_Pack) {
            spectral_pack(cards, pack.size, inst, ante);
        } else return 0;
        for (int c = 0; c < pack.size; c++) {
            if (cards[c] == RETRY) continue;
            if (cards[c] == The_Soul) {
                // Look for perkeo from S_SOUL source
                item value = next_joker(inst, S_Soul, ante);
                if (value == Perkeo) {
                    *perkeo = true;
                }
            }
        }
        return score;
    }

    // Generate next x jokers that will be in the pack
    jokerdata jokers[4];
    buffoon_pack_detailed(jokers, pack.size, inst, ante);

    long score = 0;
    for (int index = 0; index < pack.size; index++) {
        score += scoreCard(inst, jokers[index], hack, wee, blueprint);
    }
    return score;
}

long check_next_shopitem(instance* inst, int ante, int * hack, int * wee, int * blueprint) {
  shopitem sItem = next_shop_item(inst, ante);
  if (sItem.type != ItemType_Joker) {
    return 0;
  }
  return scoreCard(inst, sItem.joker, hack, wee, blueprint);
}

long filter(instance* inst) {
    set_deck(inst, Anaglyph_Deck);
    set_stake(inst, White_Stake);
    init_locks(inst, 1, false, false);

    int hack = 0;
    int wee = 0;
    int score = 0;
    int blueprint = 0;
    bool perkeo = false;
    int nt = 0;
    int dt = 0;
    bool observatory = false;
    bool antimatter = false;
    
    for (int a = 1; a <= 7; a ++) {
        init_unlocks(inst, a, false);

        item voucher = next_voucher(inst, a);
        if (voucher == Telescope) {
            activate_voucher(inst, Telescope);
        } else if (voucher == Observatory) {
            activate_voucher(inst, Observatory);
            observatory = true;
        } else if (voucher == Blank) {
            activate_voucher(inst, Blank);
        } else if (voucher == Antimatter) {
            antimatter = true;
        }

        item tag1 = next_tag(inst, a);
        item tag2 = next_tag(inst, a);
        if (tag1 == Negative_Tag) {
            nt++;
        } else if (tag1 == Double_Tag) {
            dt++;
        }
        if (tag2 == Negative_Tag) {
            nt++;
        } else if (tag2 == Double_Tag) {
            dt++;
        }

        score += check_next_shopitem(inst, a, &hack, &wee, &blueprint);
        score += check_next_shopitem(inst, a, &hack, &wee, &blueprint);
        score += check_next_shopitem(inst, a, &hack, &wee, &blueprint);
        score += check_next_shopitem(inst, a, &hack, &wee, &blueprint);
        
        if (a > 1) {
            score += check_next_shopitem(inst, a, &hack, &wee, &blueprint);
            score += check_next_shopitem(inst, a, &hack, &wee, &blueprint);
            
        }
        if (a > 2) {
            score += check_next_shopitem(inst, a, &hack, &wee, &blueprint);
            score += check_next_shopitem(inst, a, &hack, &wee, &blueprint);
        }
        if (a > 3) {
            score += check_next_shopitem(inst, a, &hack, &wee, &blueprint);
            if (inst->params.showman == false) return 0;
        }
        score += check_next_pack(inst, a, &hack, &wee, &perkeo, &blueprint);
        score += check_next_pack(inst, a, &hack, &wee, &perkeo, &blueprint);
        score += check_next_pack(inst, a, &hack, &wee, &perkeo, &blueprint);
        score += check_next_pack(inst, a, &hack, &wee, &perkeo, &blueprint);
        if (a > 1) {
            score += check_next_pack(inst, a, &hack, &wee, &perkeo, &blueprint);
            score += check_next_pack(inst, a, &hack, &wee, &perkeo, &blueprint);
        }
    }

    if (wee == 0 || hack == 0 || score == 0 || perkeo == false || blueprint == 0 || observatory == false) {
        return 0;
    }

  return score*100 + (dt+nt > 9 ? 9 : dt+nt+(antimatter ? 1 : 0));
}