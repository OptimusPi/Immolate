#include "lib/immolate.cl"
long filter(instance* inst) {
    set_deck(inst, Erratic_Deck);
    int scores[13] = {0};
    item deck[52];
    init_deck(inst, deck);

    long score = 0;
     for (int i = 0; i < 52; i += 4) {
        int r0 = rank(deck[i]) - _2;
        int r1 = rank(deck[i + 1]) - _2;
        int r2 = rank(deck[i + 2]) - _2;
        int r3 = rank(deck[i + 3]) - _2;

        scores[r0]++;
        scores[r1]++;
        scores[r2]++;
        scores[r3]++;

        if (scores[r0] > score) score = scores[r0];
        if (scores[r1] > score) score = scores[r1];
        if (scores[r2] > score) score = scores[r2];
        if (scores[r3] > score) score = scores[r3];
    }

    return score;
}