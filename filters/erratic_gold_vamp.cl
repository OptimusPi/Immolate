// Searches for an Erratic Deck seed with lots of a type of suit
#include "lib/immolate.cl"
long filter(instance* inst) {
    set_deck(inst, Erratic_Deck);
    if (next_shop_item(inst, 1).value != B)
    if (next_shop_item(inst, 1).value != Walkie_Talkie)
    if (next_shop_item(inst, 1).value != Walkie_Talkie)
    if (next_shop_item(inst, 1).value != Walkie_Talkie)
        return 0;


    int score = 0;
    item deck[52];
    init_deck(inst, deck);
    for (int i = 0; i < 52; i++) {
        if (rank(deck[i]) == _4) score++;
        if (suit(deck[i]) == _10) score++;
    }
    return score;
}