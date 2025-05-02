#include "lib/immolate.cl"

long filter(instance* inst) {
    // Configuration
    set_deck(inst, Ghost_Deck);
    set_stake(inst, Black_Stake);

    long score = 0;
    int counts[3] = {0, 0, 0}; // Index 0: Turtle_Bean, 1: Troubadour, 2: Seltzer, 3: Diet_Cola

    for (int ante = 1; ante <= 5; ante++) {
        init_unlocks(inst, ante, false);
        int shopItems = (ante == 1) ? 6 : 8;

        for (int i = 0; i < shopItems; i++) {
            shopitem item = next_shop_item(inst, ante);

            if (item.type == ItemType_Joker) {
                switch (item.value) {
                    case Turtle_Bean:
                        counts[0]++;
                        score += 300 * (6 - ante);
                        break;
                    case Seltzer:
                        counts[1]++;
                        score += 200 * (6 - ante);
                        break;
                    case Diet_Cola:
                        counts[2]++;
                        score += 200 * (6 - ante);
                        break;
                    default: break;
                }
            }
        }
    }

    // Require at least one target item
    if (counts[0] + counts[1] + counts[2] == 0) {
        return 0;
    }

    return score;
}