// Searches for an Erratic Deck seed with lots of a rank
#include "lib/immolate.cl"

long scoreCard(jokerdata joker, int * hack, int * wee) {
    if (joker.joker == Hack) {
        *hack += 1;
    }
    else if (joker.joker == Wee_Joker) {
        *wee += 1;
    } else { 
        return 0;
    }
    return 1;
}

long check_next_pack(instance* inst, int ante, int * hack, int * wee) {
    pack pack = pack_info(next_pack(inst, ante));

    if (pack.type != Buffoon_Pack) {
        return 0;
    }

    // Generate next x jokers that will be in the pack
    jokerdata jokers[4];
    buffoon_pack_detailed(jokers, pack.size, inst, ante);

    long score = 0;
    for (int index = 0; index < pack.size; index++) {
        score += scoreCard(jokers[index], hack, wee);
    }
    return score;
}

long check_next_shopitem(instance* inst, int ante, int * hack, int * wee) {
  shopitem sItem = next_shop_item(inst, ante);
  return scoreCard(sItem.joker, hack, wee);
}

long filter(instance* inst) {
    set_deck(inst, Erratic_Deck);
    init_locks(inst, 1, false, false);
    item deck[52];
    init_deck(inst, deck);
    long twos = 0;
    long aces = 0;

    for (int i = 0; i < 52; i++) {
        if (rank(deck[i]) == _2)twos++;
        if (rank(deck[i]) == Ace)aces++;
        if (i > 20 && twos < 5) return 0;
    }

 
  int hack = 0;
  int wee = 0;
  int score = 0;

// Unrolled loop for a=1
score += check_next_shopitem(inst, 1, &hack, &wee);
score += check_next_shopitem(inst, 1, &hack, &wee);
score += check_next_pack(inst, 1, &hack, &wee);
score += check_next_shopitem(inst, 1, &hack, &wee);
score += check_next_shopitem(inst, 1, &hack, &wee);
score += check_next_pack(inst, 1, &hack, &wee);

// Unrolled loop for a=2
score += check_next_shopitem(inst, 2, &hack, &wee);
score += check_next_shopitem(inst, 2, &hack, &wee);
score += check_next_pack(inst, 2, &hack, &wee);
score += check_next_shopitem(inst, 2, &hack, &wee);
score += check_next_shopitem(inst, 2, &hack, &wee);
score += check_next_pack(inst, 2, &hack, &wee);

// Unrolled loop for a=3
score += check_next_shopitem(inst, 3, &hack, &wee);
score += check_next_shopitem(inst, 3, &hack, &wee);
score += check_next_pack(inst, 3, &hack, &wee);
score += check_next_shopitem(inst, 3, &hack, &wee);
score += check_next_shopitem(inst, 3, &hack, &wee);
score += check_next_pack(inst, 3, &hack, &wee);

  if (hack == 0 || wee == 0) {
      return 0;
  }

  return twos * 1000 + score;
}