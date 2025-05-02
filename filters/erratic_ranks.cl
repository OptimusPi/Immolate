// Searches for an Erratic Deck seed with lots of a rank
#include "lib/immolate.cl"
long filter(instance* inst) {
    set_deck(inst, Erratic_Deck);
    int16 scores;
    for (int i = 0; i < 13; i++) scores[i] = 0;
    item deck[52];
    init_deck(inst, deck);
    int score = 0;
    for (int i = 0; i < 52; i++) {
    int _rank = rank(deck[i])-_2;
       if (++scores[_rank] > score) {
           score = scores[_rank];
       }
    }
    return score;
}