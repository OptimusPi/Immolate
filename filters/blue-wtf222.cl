// Searches for an Erratic Deck seed with lots of a rank
#include "lib/immolate.cl"

bool isGood(item joker) {
    return joker == Brainstorm || joker == Blueprint || joker == Wee_Joker || joker == Hack;
}
long checkShopItem(instance* inst, int ante, item compare) {
    long score = 0;
    shopitem _item = next_shop_item(inst, ante);
    if (_item.type == ItemType_Joker) {
        if (_item.value == Showman) {
            inst->params.showman = true;
        }
        if (compare != RETRY && compare == _item.value) {
            score += 10;
        }
        else if (compare == RETRY && isGood(_item.value)) {
            if (_item.joker.edition == Negative) {
                score += 100;
            } else {
                score += 10;
            }
            return score;
        }
        else if (_item.joker.edition == Negative) {
            score += 1;
        }
    }
    return score;
}
long filter(instance* inst) {
    inst->params.showman = true;
    set_deck(inst, Erratic_Deck);
    set_stake(inst, White_Stake);
    item deck[52];
    init_deck(inst, deck);
    long twos = 0;

    for (int i = 0; i < 52; i++) {
        item r = rank(deck[i]);
        if (r == _2) twos++;
    }
    if (twos < 8) return 0;
    
    long score = 0;
    score += checkShopItem(inst, 1, Showman);
    score += checkShopItem(inst, 1, Showman);
    score += checkShopItem(inst, 1, Showman);
    score += checkShopItem(inst, 1, Showman);
    if (score < 10) return 0;
    for (int i = 2; i <= 8; i++) {
        score += checkShopItem(inst, i, RETRY);
        score += checkShopItem(inst, i, RETRY);
        score += checkShopItem(inst, i, RETRY);
        score += checkShopItem(inst, i, RETRY);
    }

  return 100*score+twos;
}