// Searches for seeds with Observatory in ante 2 and Perkeo in ante 1 or 2
#include "lib/immolate.cl"
#define CACHE_SIZE 200
#define _DFirst 100000000
#define _D1 10000000
#define _D2 1000000
#define _D3 100000
#define _D4 10000
#define _D5 1000
#define _D6 100
#define _D7 10
#define _DLast 1
#define FIXED_FILTER_CUTOFF
//#define _debugPrints 1

long filter(instance *inst) {
  set_deck(inst, Anaglyph_Deck);
  init_locks(inst, 1, false, false);
  item deck[52];
  init_deck(inst, deck);
  bool perkeo = false;


  // BEGIN CONFIG
  #define NUM_NEEDS 4
  #define NUM_WANTS 5
  #define NEED_BY_ANTE 2
  #define WANT_BY_ANTE 14
  #define NEED_BY_ANTE_PERKEO 7
  item Needs[NUM_NEEDS] = { Showman, Ankh, Turtle_Bean, Ouija };
  bool ScoreNeeds[NUM_NEEDS] = { false, false, false, false };
  item Wants[NUM_WANTS] = { Ouija, Turtle_Bean, Troubadour, Hiker, Seltzer };
  int ScoreWants[NUM_WANTS] = { 1, 1, 0, 0, 0 };
  // END CONFIG

  /// BEGIN OBSERVATORY & NEGATIVE TAGS SEARCH
  int ScoreDigits[5] = {_D4, _D5, _D6, _D7, _DLast};
  int observatoryAnte = 99;
  int telescopeAnte = 99;
  int negTags = 0;
  int negJokers = 0;
  item cards[128]; // Declare the array
  // Initialize all elements to RETRY
  for (int i = 0; i < 128; i++) {
      cards[i] = RETRY;
  }
  int shCount = 0;
  bool magic = false;
    int negLeg = 0;
bool daFirst = true;
int negBlues = 0;
  // Step 1 Voucher
  // Step 2 Tags
  // Step 3 Shop Queue
  // Step 4 Packs ?
  int antesToSearch = WANT_BY_ANTE > 8 ? WANT_BY_ANTE : 8;
  for (int ante = 1; ante <= antesToSearch; ante++) {
    init_unlocks(inst, ante, false); 
    // init_unlocks(inst, ante, false); // REMOVED: Avoid resetting state per ante
    item current_voucher = next_voucher(inst, ante); // Store the result of the first voucher check
    #ifdef _debugPrints
    printf("Ante %d Voucher: \r\n", ante);
    print_item(current_voucher);
    printf("\n");
    #endif
    if (telescopeAnte == 99 && current_voucher == Telescope) {
      telescopeAnte = ante;
      activate_voucher(inst, Telescope); // RESTORED: Necessary to enable Observatory check
    }
    else if (telescopeAnte != 99 && observatoryAnte == 99 && current_voucher == Observatory) { // Check the stored voucher
      observatoryAnte = ante;
      // activate_voucher(inst, Observatory); // REMAINS REMOVED: Don't simulate activation in filter
    }
    if (next_tag(inst, ante) == Negative_Tag)
      negTags++;
    next_orbital_tag(inst);
    if (next_tag(inst, ante) == Negative_Tag)
      negTags++;
    next_orbital_tag(inst);
    next_orbital_tag(inst);
    int cardsIndex = 0;
    shCount = ante == 1 ? 4 : 6 + ante;

    if (ante == WANT_BY_ANTE) {
      continue;
    }

    for (int sh = 0; sh < shCount; sh++) {
      shopitem shItem = next_shop_item(inst, ante);
      if (shItem.value == RETRY) continue;
      if (shItem.type == ItemType_Joker) {
        #ifdef _debugPrints
        printf("Shop item %d: ", sh);
        print_item(shItem.value);
        #endif
        if (shItem.joker.edition == Negative)
          negJokers++;
      }
      cards[cardsIndex++] = shItem.value;
    }

    int packChecks = ante == 1 ? 4 : 6;
    #ifdef _debugPrints
    printf("performing %d pack checks for ante %d\n", packChecks, ante);
    #endif
    
    
    for (int p = 0; p < packChecks; p++) {
      item cardsTemp[5] = {RETRY, RETRY, RETRY, RETRY, RETRY};
      pack _pack = pack_info(next_pack(inst, ante));
      if (_pack.type == Arcana_Pack) 
        arcana_pack(cardsTemp, _pack.size, inst, ante);
      else if (_pack.type == Spectral_Pack)
        spectral_pack(cardsTemp, _pack.size, inst, ante);
      else if (_pack.type == Buffoon_Pack) {
        jokerdata jkrDet[5];
        buffoon_pack_detailed(jkrDet, _pack.size, inst, ante);
        for (int i = 0; i < _pack.size; i++) {
          cardsTemp[i] = jkrDet[i].joker;
          if (jkrDet[i].edition == Negative) {
            negJokers++;
          }
          if (jkrDet[i].edition == Negative && (jkrDet[i].joker == Blueprint || jkrDet[i].joker == Brainstorm)) {
            negBlues++;
          }
        }
      }
      else continue;
      #ifdef _debugPrints
      printf("Opening Pack %d:\n", p);
      #endif
      for (int t = 0; t < _pack.size; t++) {
        #ifdef _debugPrints
        print_item(cardsTemp[t]);
        printf(" ");
        #endif

        if (cardsTemp[t] == The_Soul) {
          jokerdata jkrData = next_joker_with_info(inst, S_Soul, ante);

          #ifdef _debugPrints
          printf("!!! Found Legendary Joker at Ante: %d\n", ante);
          print_item(jkrData.joker);
          
          #endif

          if (jkrData.edition == Negative) {
            negLeg++;
          }
        
          for (int ww = 0; ww < NUM_WANTS; ww++) {
            if (The_Soul == Wants[ww]) {
              ScoreWants[ww]++;
            }
          }

          cards[cardsIndex++] = jkrData.joker;
        } else {
          cards[cardsIndex++] = cardsTemp[t];
        }
      }
      #ifdef _debugPrints
      printf("\n\n");
      printf("cardsIndex: %d\n", cardsIndex);
      #endif
    }

    #ifdef _debugPrints
    printf("\n\n  --  Time to check the card packs.  --\n");
    #endif
    for (int c = 0; c < 126; c++) {
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
      if (jkr == Perkeo) {
        #ifdef _debugPrints
        printf("Found Perkeo at Ante: %d\n", ante);
        #endif
        perkeo = true;
      }

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
    if (ante == NEED_BY_ANTE_PERKEO)
    {
        if (perkeo == false) return 0;
    }
  }
  if (observatoryAnte == 99)
    return 0; // Observatory not found

  long score = 0;
  long satisfiedWants = negLeg+negJokers+negTags;
  for (int w = 0; w < NUM_WANTS; w++) {
    if (ScoreWants[w] > 0)
      satisfiedWants += 10;
    satisfiedWants += ScoreWants[w];

    score += ScoreWants[w]  * ScoreDigits[w]; // Middle digits
  }
  //score += satisfiedWants   * _D1;
  score += negTags          * _DFirst;
  score += negLeg         * _D1;
  score += negBlues        * _D2;
  score += negJokers        * _D3;

  return score;
}
