
// Searches for seeds with Observatory in ante 2 and Perkeo in ante 1 or 2
#include "lib/immolate.cl"
#define CACHE_SIZE 128
#define _debugPrints 1

#define _DFirst 100000000
#define _D1 10000000
#define _D2 1000000
#define _D3 100000
#define _D4 10000
#define _D5 1000
#define _D6 100
#define _D7 10
#define _DLast 1

long filter(instance *inst) {
  #ifdef _debugPrints
  printf("Starting filter\n");
  #endif
  set_deck(inst, Erratic_Deck);
    set_stake(inst, White_Stake);
    item deck[52];
    init_deck(inst, deck);
    long twos = 0;
    init_locks(inst, 1, false, false);

for (int i = 0; i < 52; i++) {
    item r = rank(deck[i]);
    if (r == _2) twos++;
}


  // BEGIN CONFIG
  #define NUM_NEEDS 2
  #define NUM_WANTS 6
  #define NEED_BY_ANTE 4
  #define PERKEO_BY_ANTE 4
  #define TOTAL_ANTE_SEARCH 12
  #define WANT_BY_ANTE 10
  item Needs[NUM_NEEDS] = { Hack, Wee_Joker };
  bool ScoreNeeds[NUM_NEEDS] = { false, false };
  item Wants[NUM_WANTS] = { Showman, Blueprint, Brainstorm, DNA, Burnt_Joker, Space_Joker };
  int ScoreWants[NUM_WANTS] = {0, 0, 0, 0, 0, 0};
  // END CONFIG

  /// BEGIN OBSERVATORY & NEGATIVE TAGS SEARCH
  int ScoreDigits[7] = {_D1, _D2, _D3, _D4, _D5, _D6, _D7};
  int observatoryAnte = 99;
  int telescopeAnte = 99;
  int negTags = 0;
  for (int ante = 1; ante <= 4; ante++) {
    init_unlocks(inst, ante, false);
    if (telescopeAnte == 99 && next_voucher(inst, ante) == Telescope) {
      telescopeAnte = ante;
      activate_voucher(inst, Telescope);
    }
    if (telescopeAnte!= 99 && observatoryAnte == 99 && next_voucher(inst, ante) == Observatory) {
      observatoryAnte = ante;
    }
    if (next_tag(inst, ante) == Negative_Tag)
      negTags++;
    if (next_tag(inst, ante) == Negative_Tag)
      negTags++;
    next_orbital_tag(inst);
  }

  if (negTags < 1)
    return 0;

  if (observatoryAnte == 99) {
    #ifdef _debugPrints
    printf("Returning Score=0 because Observatory not found\n");
    #endif
    return 0;
  } else {
    #ifdef _debugPrints
    printf("Found Observatory at ante %d\n", observatoryAnte);
    #endif
  }
  // END OBSERVATORY / NEGATIVE TAGS SEARCH
  bool perkeo = false;
  // SEARCH FOR NEEDS
  int negJokers = 0;
  for (int ante = 1; ante <= TOTAL_ANTE_SEARCH; ante++) {
    #ifdef _debugPrints
    printf("checking ante %d\n", ante);
    #endif
    init_unlocks(inst, ante, false);
    item cards[36] = {
        RETRY, RETRY, RETRY, RETRY, RETRY, RETRY, RETRY, RETRY, // 8
        RETRY, RETRY, RETRY, RETRY, RETRY, RETRY, RETRY, RETRY, // 16
        RETRY, RETRY, RETRY, RETRY, RETRY, RETRY, RETRY, RETRY, // 24
        RETRY, RETRY, RETRY, RETRY, RETRY, RETRY, RETRY, RETRY, // 32
        RETRY, RETRY, RETRY, RETRY // 36
    };
    int cardsIndex = 0;
    cards[30] = next_shop_item(inst, ante).value;
    cards[31] = next_shop_item(inst, ante).value;
    cards[32] = next_shop_item(inst, ante).value;
    cards[33] = next_shop_item(inst, ante).value;
    if (ante > 1) {
      cards[34] = next_shop_item(inst, ante).value;
      cards[35] = next_shop_item(inst, ante).value;
    }
    #ifdef _debugPrints
    printf("- Shop items:\n", ante);
    print_item(cards[30]);
    printf(" ");
    print_item(cards[31]);
    printf(" ");
    print_item(cards[32]);
    printf(" ");
    print_item(cards[33]);
    printf(" ");
    print_item(cards[34]);
    printf(" ");
    print_item(cards[35]);
    printf("\n(cardsIndex: %d)\n\n", cardsIndex);
    #endif
    int packChecks = ante == 1 ? 4 : 6;

    #ifdef _debugPrints
    printf("performing %d pack checks for ante %d\n", packChecks, ante);
    #endif
    bool magic = false;
    int negatives= 0;

    for (int p = 0; p < packChecks; p++) {
      item cardsTemp[5] = {RETRY, RETRY, RETRY, RETRY, RETRY};
      pack _pack = pack_info(next_pack(inst, ante));
      if (_pack.type == Arcana_Pack)
        arcana_pack(cardsTemp, _pack.size, inst, ante);
      else if (_pack.type == Spectral_Pack)
        spectral_pack(cardsTemp, _pack.size, inst, ante);
      else if (_pack.type == Buffoon_Pack) {
        jokerdata jkrs[5];
        buffoon_pack_detailed(jkrs, _pack.size, inst, ante);
        for (int i = 0; i < _pack.size; i++) {
            if (jkrs[i].edition == Negative)
                negatives++;
            cardsTemp[i] = jkrs[i].joker;
        }
      }
      else continue;
      #ifdef _debugPrints
      printf("Opening Pack %d:\n", p);
      #endif
      for (int t = 0; t < 5; t++) {
        #ifdef _debugPrints
        print_item(cardsTemp[t]);
        printf(" ");
        #endif
        cards[cardsIndex++] = cardsTemp[t];
      }
      #ifdef _debugPrints
      printf("\n\n");
      printf("cardsIndex: %d\n", cardsIndex);
      #endif
    }

    #ifdef _debugPrints
    printf("\n\n  --  Time to check the card packs.  --\n");
    #endif
    for (int c = 0; c < 36; c++) {
      int type = 0;
      item jkr = cards[c];
      if (jkr == RETRY)
        continue;
      if (jkr == Showman) {
        inst->params.showman = true;
      }

      if (jkr == The_Magician)
        magic = true;
      if (jkr == Lucky_Cat && !magic)
        continue;

      if (jkr == The_Soul)
        jkr = next_joker(inst, S_Soul, ante);

      if (jkr == Perkeo)
        perkeo = true;

      for (int x = 0; x < NUM_NEEDS; x++) {
        if (jkr == Needs[x] && (ScoreNeeds[x] == 0 || inst->params.showman == true)) {
          ScoreNeeds[x] = true;
          break;
        }
      }
      for (int x = 0; x < NUM_WANTS; x++) {
        if (jkr == Wants[x] && (ScoreWants[x] == 0 || inst->params.showman == true)) {
          ScoreWants[x]++;
          break;
        }
      }
    }
    if (ante == PERKEO_BY_ANTE)
    {
         if (perkeo == false) return 0;
    }
    if (ante == NEED_BY_ANTE) 
    {
        for (int n = 0; n < NUM_NEEDS; n++) {
          if (ScoreNeeds[n] == false) {
          #ifdef _debugPrints
            printf("Returning Score=0 because item never found\n");
            print_item(Needs[n]);
          #endif
            return 0;
          }
        }
    }
  }

  long score = 0;
  long satisfiedWants = 0;
  for (int w = 0; w < NUM_WANTS; w++) {
    if (ScoreWants[w] > 0)
      satisfiedWants++;
    score += ScoreWants[w] * ScoreDigits[w]; // Middle digits
  }
  score += (negTags+satisfiedWants) * _DFirst; // first digit
  score += twos * _DLast; // last digit (8th)

  return score;
}