// Searches for seeds with Observatory in ante 2 and Perkeo in ante 1 or 2
#include "lib/ouiji.cl"
#define CACHE_SIZE 256
#define FIXED_FILTER_CUTOFF 1

OuijiResult ouiji_filter(instance* inst, __global OuijiConfig* config) {
#ifdef _debugPrints
  printf("Starting filter\n");
#endif
  set_deck(inst, Anaglyph_Deck);
  set_stake(inst, White_Stake);
  init_locks(inst, 1, false, true);

  // Default max search ante if config doesn't specify individual antes
  int maxSearchAnte = config->maxSearchAnte > 0 ? config->maxSearchAnte : 8;
  
  // Initialize score arrays
  bool ScoreNeeds[MAX_DESIRES_KERNEL];
  int ScoreWants[MAX_DESIRES_KERNEL];

  shopitem cards[128]; // Declare the array
  // Initialize all elements to RETRY
  for (int i = 0; i < 128; i++) {
    shopitem shit = {ItemType_Joker, RETRY, RETRY};
    cards[i] = shit;
  }
  int shCount = 0;
  bool magic = false;

  bool firstLeg = true;
  bool firstBlue = true;
  OuijiResult result = {0}; // Initialize all members to 0/false
  result.valid = true;

  // Search through all antes up to maxSearchAnte
  for (int ante = 1; ante <= maxSearchAnte; ante++) {
    init_unlocks(inst, ante, false);
    
    item voucher = next_voucher(inst, ante);
#ifdef _debugPrints
    printf("Ante %d Voucher: \r\n", ante);
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
      if (config->Needs[x].value == smallBlindTag || config->Needs[x].value == bigBlindTag) {
        ScoreNeeds[x] = true;
      }
      // Check the vouchers
      if (config->Needs[x].value == voucher) {
        ScoreNeeds[x] = true;
      }
    }

    int cardsIndex = 0;

    // Check antes for desires!
    shCount = ante == 1 ? 4 : 6 + ante;
    for (int sh = 0; sh < shCount; sh++) {
      shopitem shItem = next_shop_item(inst, ante);
      if (shItem.value == RETRY)
        continue;
#ifdef _debugPrints
        printf("Shop item %d: ", sh);
        print_item(shItem.value);
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
      }
      else if (_pack.type == Spectral_Pack) {
        spectral_pack(cardsTemp, _pack.size, inst, ante);
      }
      else if (_pack.type == Buffoon_Pack) {
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
              ScoreNeeds[ww]++;
            }
            if (The_Soul == config->Wants[ww].value) {
              ScoreNeeds[ww]++;
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
    for (int c = 0; c < 126; c++) {
      shopitem shit = cards[c];
      if (shit.value == RETRY)
        continue;
      if (shit.value == Showman) {
        inst->params.showman = true;
      }

      if (shit.value == Perkeo) {
#ifdef _debugPrints
        printf("Found Perkeo at Ante: %d\n", ante);
#endif
      }

      // Score check for Needs
      for (int x = 0; x < config->numNeeds; x++) {
        // Fitst handle Jokers
        if (config->Needs[x].type == DESIRE_JOKER && shit.type == ItemType_Joker) {
          // Check for Joker value match
          if (config->Needs[x].value == shit.value && (config->Needs[x].joker.edition != No_Edition || config->Needs[x].joker.edition == shit.joker.edition)) {
            ScoreNeeds[x] = true;
          }
        }
        else {
          // Check value of non-Joker items
          if (config->Needs[x].value == shit.value) {
            ScoreNeeds[x] = true;
          }
        }
      }

      // Score check for Wants
      for (int x = 0; x < config->numNeeds; x++) {
        // Fitst handle Jokers
        if (config->Wants[x].type == DESIRE_JOKER && shit.type == ItemType_Joker) {
          // Check for Joker value match
          if (config->Wants[x].value == shit.value && (config->Wants[x].joker.edition != No_Edition || config->Wants[x].joker.edition == shit.joker.edition)) {
            ScoreWants[x]++;
          }
        }
        else {
          // Check value of non-Joker items
          if (config->Needs[x].value == shit.value) {
            ScoreWants[x]++;
          }
        }
      }
    } // Done scoring collection of cards

    // Check per-need ante requirements at the end of each ante
    for (int n = 0; n < config->numNeeds; n++) {
      // If this need's ante requirement is the current ante, check if it's been found
      if (config->Needs[n].desireByAnte == ante && ScoreNeeds[n] == false) {
#ifdef _debugPrints
        printf("Returning Score=0 because item never found by its required ante %d\n", ante);
        print_item(Needs[n]);
#endif
        result.valid = false;
        return result;
      }
    }
  } // End scoring cards for this ante

  for (int w = 0; w < config->numWants; w++) {
    result.TotalScore += ScoreWants[w] > 0 ? 10 : 0;
    result.TotalScore += ScoreWants[w];
    result.ScoreWants[w] = ScoreWants[w];
  };
  result.valid = true;

  return result;
}
