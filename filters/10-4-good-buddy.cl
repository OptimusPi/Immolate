#define FIXED_FILTER_CUTOFF
#include "lib/immolate.cl"
long filter(instance* inst) {
    set_deck(inst, Erratic_Deck);
    long score = 200;
    if (next_shop_item(inst, 1).value != Walkie_Talkie)
    if (next_shop_item(inst, 1).value != Walkie_Talkie)
    {
        if (next_shop_item(inst, 2).value != Walkie_Talkie)
        if (next_shop_item(inst, 2).value != Walkie_Talkie)
            score -= 100;
    }
    if (next_shop_item(inst, 1).value != Even_Steven)
    if (next_shop_item(inst, 1).value != Even_Steven)
    {
        if (next_shop_item(inst, 2).value != Even_Steven)
        if (next_shop_item(inst, 2).value != Even_Steven)
        if (next_shop_item(inst, 2).value != Even_Steven)
        if (next_shop_item(inst, 2).value != Even_Steven)
            score -= 100;
    }

    item deck[52];
    init_deck(inst, deck);
    for (int i = 0; i < 52; i++) {
        if (rank(deck[i]) == _4) score++;
        if (rank(deck[i]) == _10) score++;
    }
    return score;
}