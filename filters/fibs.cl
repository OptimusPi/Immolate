// Searches for an Erratic Deck seed with lots of a rank
#include "lib/immolate.cl"

int scoreCard(jokerdata joker, int* dna, int* bp, int* tradingCard, int* fibonaccis, int * hack, int * wee) {
    int score = 0;

    if (joker.edition == Negative) {
        score += 40;
    }

    if (joker.joker == DNA) {
        *dna += 1;
        score += 2;
    }
    else if (joker.joker == Hack) {
        *hack += 3;
        score += 2;
    }
    else if (joker.joker == Wee_Joker) {
        *wee += 1;
        score += 2;
    }
    else if (joker.joker == Splash) {
        score += 2;
    }
    else if (joker.joker == Trading_Card) {
        *tradingCard += 1;
        score += 1;
    }
    else if (joker.joker == Fibonacci) {
        *fibonaccis += 1;
        score += 2;
    }
    else if (joker.joker == Oops_All_6s || joker.joker == Showman || joker.joker == Invisible_Joker || joker.joker == Space_Joker || joker.joker == Burnt_Joker) {
        score += 6;
    }
    else if (joker.joker == Blueprint || joker.joker == Brainstorm ) {
        score += 2;
        *bp += 1;
    } else {
        if (joker.edition == Negative) {
            return 10;
        } else {
            return 0;
        }
    }

    if (joker.edition == Negative) {
        score += 100;
    }

    return score;
}
int check_next_pack(instance* inst, int ante, int * dna, int * bp, int * tradingCard, int * fibonaccis, int * hack, int * wee) {
    pack pack = pack_info(next_pack(inst, ante));

    if (pack.type != Buffoon_Pack) {
        return 0;
    }

    // Generate next x jokers that will be in the pack
    jokerdata jokers[4];
    buffoon_pack_detailed(jokers, pack.size, inst, ante);

    int score = 0;
    for (int index = 0; index < pack.size; index++) {
        score += scoreCard(jokers[index], dna, bp, tradingCard, fibonaccis, hack, wee);
    }
    return score;
}

int check_next_shopitem(instance* inst, int ante, int * dna, int * bp, int * tradingCard, int * fibonaccis, int * hack, int * wee) {
  shopitem sItem = next_shop_item(inst, ante);
  return scoreCard(sItem.joker, dna, bp, tradingCard, fibonaccis, hack, wee);
}

long filter(instance* inst) {
    set_deck(inst, Erratic_Deck);
    set_stake(inst, Black_Stake);
    init_locks(inst, 1, false, false);
    int score = 0;

    item deck[52];
    init_deck(inst, deck);
    int almostFibs = 0;
    int fibs = 0;
    for (int i = 0; i < 52; i++) {
        item cardRank = rank(deck[i]);
        switch (cardRank) {
            case _2:
            case _3:
            case _5:
                fibs += 1;
                break;
            default:
            break;
        }
    }
 
  int dna = 0;
  int bp = 0;
  int tradingCard = 0;
  int fibonaccis = 0;
  int hack = 0;
  int wee = 0;
  

  // Check "Ante 1" - (2 shops)
  score += check_next_shopitem(inst, 1, &dna, &bp, &tradingCard, &fibonaccis, &hack, &wee);
  score += check_next_shopitem(inst, 1, &dna, &bp, &tradingCard, &fibonaccis, &hack, &wee);
  score += check_next_pack(inst, 1, &dna, &bp, &tradingCard, &fibonaccis, &hack, &wee);
  score += check_next_shopitem(inst, 1, &dna, &bp, &tradingCard, &fibonaccis, &hack, &wee);
  score += check_next_shopitem(inst, 1, &dna, &bp, &tradingCard, &fibonaccis, &hack, &wee);
  score += check_next_pack(inst, 1, &dna, &bp, &tradingCard, &fibonaccis, &hack, &wee);
  score = score > 1 ? score + 1 : score - 1;

  if (fibonaccis == 0) {
      return 0; // no point in continuing if we didn't get anything useful
  }

  // Check "Ante 2" - (3 shops)
  score += check_next_shopitem(inst, 2, &dna, &bp, &tradingCard, &fibonaccis, &hack, &wee);
  score += check_next_shopitem(inst, 2, &dna, &bp, &tradingCard, &fibonaccis, &hack, &wee);
  score += check_next_pack(inst, 2, &dna, &bp, &tradingCard, &fibonaccis, &hack, &wee);
  score += check_next_shopitem(inst, 2, &dna, &bp, &tradingCard, &fibonaccis, &hack, &wee);
  score += check_next_shopitem(inst, 2, &dna, &bp, &tradingCard, &fibonaccis, &hack, &wee);
  score += check_next_pack(inst, 2, &dna, &bp, &tradingCard, &fibonaccis, &hack, &wee);
  score += check_next_shopitem(inst, 2, &dna, &bp, &tradingCard, &fibonaccis, &hack, &wee);

  if (hack == 0 && wee == 0) {
      return 0;
  }


  // Check "Ante 3" - (3 shops)
  score += check_next_shopitem(inst, 3, &dna, &bp, &tradingCard, &fibonaccis, &hack, &wee);
  score += check_next_shopitem(inst, 3, &dna, &bp, &tradingCard, &fibonaccis, &hack, &wee);
  score += check_next_pack(inst, 3, &dna, &bp, &tradingCard, &fibonaccis, &hack, &wee);
  score += check_next_shopitem(inst, 3, &dna, &bp, &tradingCard, &fibonaccis, &hack, &wee);
  score += check_next_shopitem(inst, 3, &dna, &bp, &tradingCard, &fibonaccis, &hack, &wee);
  score += check_next_pack(inst, 3, &dna, &bp, &tradingCard, &fibonaccis, &hack, &wee);
  score += check_next_shopitem(inst, 3, &dna, &bp, &tradingCard, &fibonaccis, &hack, &wee);
  score += check_next_shopitem(inst, 3, &dna, &bp, &tradingCard, &fibonaccis, &hack, &wee);

  if (hack == 0 || bp == 0 || wee == 0) {
      return 0;
  }

    // [fibs][][score][][]
    // 2244123
  return fibs * 1000 + score;
}