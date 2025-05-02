// Searches for an Erratic Deck seed with lots of a rank
#include "lib/immolate.cl"

long scoreCard(instance* inst, jokerdata joker, int * sock, int * baron) {
    if (joker.joker == Baron) {
        *baron += 1;
    }
    else if (joker.joker == Blueprint || joker.joker == Brainstorm) {
        return joker.edition == Negative ? 1000010 : 10;
    }
    else if (joker.joker == Invisible_Joker) {
        return joker.edition == Negative ? 1000100 : 100;
    }
    else if (joker.joker == DNA) {
        return joker.edition == Negative ? 1001000 : 1000;
    }
    else if (joker.joker == Perkeo) {
        return joker.edition == Negative ? 1010000 : 10000;
    } else { 
        return joker.edition == Negative ? 100000 : 0;
    }
    return 0;
}

long check_next_pack(instance* inst, int ante, int * sock, int * baron) {
    pack pack = pack_info(next_pack(inst, ante));

    if (pack.type != Buffoon_Pack) {
        if (pack.type == Spectral_Pack) {
            item items[5];
            spectral_pack(items, pack.size, inst, ante);
            for (int index = 0; index < pack.size; index++) {
                if (items[index] == The_Soul) {
                    jokerdata jkr = next_joker_with_info(inst, S_Soul, ante);
                    return scoreCard(inst, jkr, sock, baron);
                }
            }
        }
    }

    // Generate next x jokers that will be in the pack
    jokerdata jokers[4];
    buffoon_pack_detailed(jokers, pack.size, inst, ante);

    long score = 0;
    for (int index = 0; index < pack.size; index++) {
        score += scoreCard(inst, jokers[index], sock, baron);
    }
    return score;
}

long check_next_shopitem(instance* inst, int ante, int * sock, int * baron) {
  shopitem sItem = next_shop_item(inst, ante);
  if (sItem.type != ItemType_Joker) {
    return 0;
  }
  return scoreCard(inst, sItem.joker, sock, baron);
}

long filter(instance* inst) {
    inst->params.showman = true;
    set_deck(inst, Erratic_Deck);
    set_stake(inst, White_Stake);
    item deck[52];
    init_deck(inst, deck);
    long kings = 0;
    int sock = 0;
    int baron = 0;
    int score = 0;

    for (int i = 0; i < 52; i++) {
        item r = rank(deck[i]);
        if (r == King) kings++;
    }
    if (kings < 14) {
        return 0;
    }

    for (int a = 1; a <= 4; a ++) {
        init_unlocks(inst, a, false);
        if (next_tag(inst, a) == Negative_Tag) {
            score += 1;
        }
        if (next_tag(inst, a) == Negative_Tag) {
            score += 1;
        }
        next_orbital_tag(inst);
        score += check_next_shopitem(inst, a, &sock, &baron);
        score += check_next_shopitem(inst, a, &sock, &baron);
        score += check_next_shopitem(inst, a, &sock, &baron);
        score += check_next_shopitem(inst, a, &sock, &baron);
        if (a > 1) {
            score += check_next_shopitem(inst, a, &sock, &baron);
            score += check_next_shopitem(inst, a, &sock, &baron);
        }
        score += check_next_pack(inst, a, &sock, &baron);
        score += check_next_pack(inst, a, &sock, &baron);
        score += check_next_pack(inst, a, &sock, &baron);
        score += check_next_pack(inst, a, &sock, &baron);
        if (a > 1) {
            score += check_next_pack(inst, a, &sock, &baron);
            score += check_next_pack(inst, a, &sock, &baron);
        }
    }

  if (baron == 0) {
      return 0;
  }

  return score;
}