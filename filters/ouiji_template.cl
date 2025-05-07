// Searches for seeds with Observatory in ante 2 and Perkeo in ante 1 or 2
#include "lib/ouiji.cl"
#define CACHE_SIZE 256
//#define FIXED_FILTER_CUTOFF 1
//#define _debugPrints 1

OuijiResult ouiji_filter(instance *inst, __global OuijiConfig *config) {
#ifdef _debugPrints
  printf("Starting filter\n");
  printf("Deck id: %d\n", config->deck);
  printf("Stake id: %d\n", config->stake);
  printf("Deck: ");
  print_item(config->deck);
  printf("\n");
  printf("Stake: ");
  print_item(config->stake);
  printf("\n");

  printf("Cutoff: %ld\n", config->cutoff);
  printf("Num Needs: %d\n", config->numNeeds);
  printf("Num Wants: %d\n", config->numWants);
  printf("Max Search Ante: %d\n", config->maxSearchAnte);
  text debug_Seed = s_to_string(&inst->seed);
  printf("my seed is [%s]\n", debug_Seed.str);
#endif

  
  set_deck(inst, config->deck);
  set_stake(inst, config->stake);
  init_locks(inst, 1, false, true);

  // Default max search ante if config doesn't specify individual antes
  int maxSearchAnte = config->maxSearchAnte > 0 ? config->maxSearchAnte : 8;

  // Initialize score arrays
  bool ScoreNeeds[MAX_DESIRES_KERNEL];
  int ScoreWants[MAX_DESIRES_KERNEL];

  // Initialize all need scores to false
  for (int i = 0; i < config->numNeeds; i++) {
    ScoreNeeds[i] = false;
  }
  // Initialize all want scores to 0
  for (int i = 0; i < config->numWants; i++) {
    ScoreWants[i] = 0;
  }

  shopitem cards[128]; // Declare the array
  // Initialize all elements to RETRY
  for (int i = 0; i < 128; i++) {
    shopitem shit = {ItemType_Joker, RETRY, RETRY};
    cards[i] = shit;
  }
  int negativeJokers = 0;
  int shCount = 0;
  bool magic = false;

  bool firstLeg = true;
  bool firstBlue = true;
  OuijiResult result = {0}; // Initialize all members to 0/false
  result.valid = 1;

  // Search through all antes up to maxSearchAnte
  for (int ante = 1; ante <= maxSearchAnte; ante++) {
    init_unlocks(inst, ante, false);

    item voucher = next_voucher(inst, ante);
#ifdef _debugPrints
    printf("Ante %d Voucher: ", ante);
    print_item(voucher);
    printf("\n");
#endif
    if (ante > 1 && voucher != Hieroglyph && voucher != Petroglyph) {
      activate_voucher(inst, voucher);
    }

    item smallBlindTag = next_tag(inst, ante);
    item bigBlindTag = next_tag(inst, ante);

    for (int x = 0; x < config->numNeeds; x++) {
      // Check the tags
      if (config->Needs[x].value == smallBlindTag ||
          config->Needs[x].value == bigBlindTag) {
        ScoreNeeds[x] = true;
      }
      // Check the vouchers
      if (config->Needs[x].value == voucher) {
        ScoreNeeds[x] = true;
      }
    }

    for (int x = 0; x < config->numWants; x++) {
      // Check the tags
    if (config->Wants[x].value == smallBlindTag ||
          config->Wants[x].value == bigBlindTag) {
        ScoreWants[x]++;
      }
      // Check the vouchers
      if (config->Wants[x].value == voucher) {
        ScoreWants[x]++;
      }
    }

    int cardsIndex = 0;

    // Check antes for desires!
    shCount = ante == 1 ? 4 : ante >= 8 ? 10 : 6;
    for (int sh = 0; sh < shCount; sh++) {
      shopitem shItem = next_shop_item(inst, ante);
      if (shItem.value == RETRY)
        continue;
#ifdef _debugPrints
      printf("Shop item %d: ", sh);
      print_item(shItem.value);
      if (shItem.type == ItemType_Joker) {
        printf(" (Edition ID: %d)", shItem.joker.edition);
      }
      printf("\n");
#endif
      cards[cardsIndex++] = shItem;
    }

    int packChecks = ante == 1 ? 4 : 6;
#ifdef _debugPrints
    printf("performing %d pack checks for ante %d\n", packChecks, ante);
#endif

    for (int p = 0; p < packChecks; p++) {
      // ... existing code ...
      item cardsTemp[5] = {RETRY, RETRY, RETRY, RETRY, RETRY};
      pack _pack = pack_info(next_pack(inst, ante));
      itemtype useType = ItemType_Joker;
      if (_pack.type == Arcana_Pack) {
        arcana_pack(cardsTemp, _pack.size, inst, ante);
        useType = ItemType_Tarot;
      } else if (_pack.type == Spectral_Pack) {
        spectral_pack(cardsTemp, _pack.size, inst, ante);
        useType = ItemType_Spectral;
      } else if (_pack.type == Buffoon_Pack) {
        jokerdata jkrsTemp[5];
        buffoon_pack_detailed(jkrsTemp, _pack.size, inst, ante);

        for (int t = 0; t < _pack.size; t++) {
          shopitem shit = {ItemType_Joker, jkrsTemp[t].joker, jkrsTemp[t]};
          cards[cardsIndex++] = shit;
        }
      } else
        continue;

      for (int t = 0; t < _pack.size; t++) {
        if (cardsTemp[t] == The_Soul) {
          jokerdata jkrData = next_joker_with_info(inst, S_Soul, ante);
          for (int ww = 0; ww < MAX_DESIRES_KERNEL; ww++) {
            if (The_Soul == config->Needs[ww].value) {
              ScoreNeeds[ww] = true;
            }
            if (The_Soul == config->Wants[ww].value) {
              ScoreWants[ww]++;
            }
          }
          shopitem soulShit = {ItemType_Joker, jkrData.joker, jkrData};
          cards[cardsIndex++] = soulShit;
        } else {
          shopitem spectralShit = {useType, cardsTemp[t], RETRY};
          cards[cardsIndex++] = spectralShit;
        }
      }
    }

    // Score the entire collection
    for (int c = 0; c < cardsIndex; c++) {
      shopitem shit = cards[c];
      if (shit.value == RETRY)
        continue;
      if (shit.value == Showman) {
        inst->params.showman = true;
      }

      // Score check for Needs
      for (int x = 0; x < config->numNeeds; x++) {
        // First handle Jokers
        if (config->Needs[x].jokeredition != RETRY && shit.type == ItemType_Joker) {
          // Check for Joker value match
          if (config->Needs[x].value == shit.value) {
            item edition = config->Needs[x].jokeredition;
            if (edition == No_Edition || edition == shit.joker.edition) {
              ScoreNeeds[x] = true;
            }
          }
        } else if (config->Needs[x].value == shit.value) {
          // Check value of non-Joker items
          ScoreNeeds[x] = true;
        }
      }

      // Score check for Wants
      for (int x = 0; x < config->numWants; x++) {
        // First handle Jokers
        if (config->Wants[x].jokeredition != RETRY && shit.type == ItemType_Joker) {
          // Check for Joker value match
          if (config->Wants[x].value == shit.value) {
            item edition = config->Wants[x].jokeredition;

            if (edition == No_Edition || edition == shit.joker.edition) {
              // Add an increment only if this is the first time we've seen this
              // want OR if we have showman which allows duplicates to be useful
              ScoreWants[x] +=
                  ((ScoreWants[x] < 1) || (inst->params.showman == true)) ? 1
                                                                          : 0;
            }
          }
        } else if (config->Wants[x].value == shit.value) {
          // Check value of non-Joker items
          ScoreWants[x]++;
        }
      }

      // Score check for fancy cards
      if (shit.type == ItemType_Joker && shit.joker.edition == Negative) {
        negativeJokers++;
      }

    } // Done scoring collection of cards

    // Check per-need ante requirements at the end of each ante
    for (int n = 0; n < config->numNeeds; n++) {
      // If this need's desireByAnte is the current ante, check if it's been
      // found
      if (ante == config->Needs[n].desireByAnte && !ScoreNeeds[n]) {
        // We've reached the ante deadline for this need and it's not been found
#ifdef _debugPrints
        printf("Returning invalid result because need %d not found by its "
               "required ante %d\n",
               n, config->Needs[n].desireByAnte);
        print_item(config->Needs[n].value);
        printf("\n");
#endif
        result.valid = 0;
        return result;
      }
    }
  } // End of ante loop

  // Calculate final score
  result.TotalScore = 1;

  // Add bonus points for wants
  for (int w = 0; w < MAX_DESIRES_KERNEL; w++) {
    result.ScoreWants[w] = ScoreWants[w];
    // 1 point if this want was ever found (helps weigh it)
    result.TotalScore += ScoreWants[w] > 0 ? 10 : 0;
  }

  // Add bonus points for negative jokers
  result.NegativeJokers = negativeJokers;
  result.TotalScore += negativeJokers * 1;

  // Copy the seed to the result
  text s_str = s_to_string(&inst->seed);
  for (int i = 0; i < 9; i++)
    result.seed[i] = s_str.str[i];

  return result;
}
