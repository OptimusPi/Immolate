// Searches for an Erratic Deck seed with lots of a rank
#include "lib/immolate.cl"

long checkShopItem(instance* inst, int ante, item compare) {
    long score = 0;
    shopitem _item = next_shop_item(inst, ante);
    if (_item.type == ItemType_Joker) {
        if (_item.joker == Showman) {
            inst->params.showman = true;
        }
        if (compare == Blueprint && (_item.joker == Blueprint || _item.joker == Brainstorm)) {
            score += 10;
        }
        else if (compare == _item.joker) {
            score += 10;
        }
        else {
            if (_item.edition == Negative) {
                score += 1;
            }
        }
        if (_item.edition == Negative) {
            score += 100;
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
    
    long score = 0;
    score += checkShopItem(inst, 1, Showman);
    score += checkShopItem(inst, 1, Showman);
    score += checkShopItem(inst, 1, Showman);
    score += checkShopItem(inst, 1, Showman);
    if (score < 10) return 0;
    for (int i = 2; i <= 8; i++) {
        score += checkShopItem(inst, i, Blueprint);
        score += checkShopItem(inst, i, Blueprint);
    }
    if (score < 20) return 0;
    for (int i = 2; i <= 8; i++) {
        score += checkShopItem(inst, i, Hack);
        score += checkShopItem(inst, i, Wee_Joker);
    }

  return 100*score+twos;
}