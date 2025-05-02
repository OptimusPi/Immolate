// Searches for an Erratic Deck seed with lots of a rank
#include "lib/immolate.cl"

long filter(instance* inst) {
    set_deck(inst, Erratic_Deck);
    set_stake(inst, Black_Stake);
    init_locks(inst, 1, false, false);
    item deck[52];
    init_deck(inst, deck);
    long fibs = 0;
    int fibJokers = 0;
    int hackJokers = 0;

    shopitem sItem = next_shop_item(inst, 1);
    if (sItem.value != Fibonacci) {
        sItem = next_shop_item(inst, 1);
        if (sItem.value != Fibonacci) {
            return 0;
        }
    }
    for (int i = 0; i < 52; i++) {
        if (rank(deck[i]) == _2)fibs++;
        if (rank(deck[i]) == _3)fibs++;
        if (rank(deck[i]) == _5)fibs++;
        if (rank(deck[i]) == _6)fibs++;
        if (rank(deck[i]) == Ace)fibs++;
    }
  return fibs;
}