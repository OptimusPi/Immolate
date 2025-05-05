// Searches for seeds with Observatory in ante 2 and Perkeo in ante 1 or 2
#include "lib/ouiji.cl"
#define CACHE_SIZE 256
#define FIXED_FILTER_CUTOFF 1
#define _debugPrints 1

OuijiResult ouiji_filter(instance* inst, __global OuijiConfig* config) {
#ifdef _debugPrints
  printf("Starting filter\n");
#endif
  set_deck(inst, Anaglyph_Deck);
  set_stake(inst, White_Stake);
  init_locks(inst, 1, false, true);

  // Default max search ante if config doesn't specify individual antes
  int maxSearchAnte = config->maxSearchAnte > 0 ? config->maxSearchAnte : 8;
#ifdef _debugPrints
  printf("Max search ante: %d\n", maxSearchAnte);
#endif

  if (config->maxSearchAnte > 8) {
    config->maxSearchAnte = 8;
  }

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

  // Debug display config values
#ifdef _debugPrints
  for (int i = 0; i < config->numNeeds; i++) {
    printf("Need %d: Type=%d Value=%d", i, config->Needs[i].type, config->Needs[i].value);
    print_item(config->Needs[i].value);
    if (config->Needs[i].type == DesireType_Joker) {
      printf(" (joker edition=%d)", config->Needs[i].joker.edition);
    }
    printf(" desireByAnte=%d\n", config->Needs[i].desireByAnte);
    printf("\n");    
  }
  for (int i = 0; i < config->numWants; i++) {
    printf("Want %d: Type=%d Value=%d", i, config->Wants[i].type, config->Wants[i].value);
    print_item(config->Wants[i].value);
    if (config->Wants[i].type == DesireType_Joker) {
      printf(" (joker edition=%d)", config->Wants[i].joker.edition);
    }
    printf(" desireByAnte=%d\n", config->Wants[i].desireByAnte);
    printf("\n");
  }
#endif

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
#ifdef _debugPrints
        printf("Found Need %d from a tag in ante %d\n", x, ante);
#endif
      }
      // Check the vouchers
      if (config->Needs[x].value == voucher) {
        ScoreNeeds[x] = true;
#ifdef _debugPrints
        printf("Found Need %d from voucher in ante %d\n", x, ante);
#endif
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
              ScoreNeeds[ww] = true;
            }
            if (The_Soul == config->Wants[ww].value) {
              ScoreNeeds[ww] = true;
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

      // Score check for Needs
      for (int x = 0; x < config->numNeeds; x++) {
        // First handle Jokers
        if (config->Needs[x].type == DesireType_Joker && shit.type == ItemType_Joker) {
          // Check for Joker value match
          if (config->Needs[x].value == shit.value) {
            // Check for edition match if specified - USE MAPPING FUNCTION
            item edition = config->Needs[x].joker.edition; // This is the host ID (e.g., 397, 398)

            if (edition == No_Edition || edition == shit.joker.edition) {
              ScoreNeeds[x] = true;
            }
          }
        }
        else if (config->Needs[x].value == shit.value) {
          // Check value of non-Joker items
          ScoreNeeds[x] = true;
        }
      }

      // Score check for Wants
      for (int x = 0; x < config->numWants; x++) {
#ifdef _debugPrints
        printf("Checking want %d (type=%d value=%d) against shop item (type=%d value=%d)\n", 
               x, config->Wants[x].type, config->Wants[x].value, shit.type, shit.value);
#endif
        // First handle Jokers
        if (config->Wants[x].type == DesireType_Joker && shit.type == ItemType_Joker) {
          // Check for Joker value match
          if (config->Wants[x].value == shit.value) {
#ifdef _debugPrints
            printf("Found Want Joker: %d in ante %d", shit.value, ante);
#endif
            item edition = config->Wants[x].joker.edition; // FIX: Use 'item' type

           if (edition == No_Edition || edition == shit.joker.edition) {
              // Add an increment only if this is the first time we've seen this want
              // OR if we have showman which allows duplicates to be useful
              ScoreWants[x] += ((ScoreWants[x] < 1) || (inst->params.showman == true)) ? 1 : 0;
#ifdef _debugPrints
              printf("  - Found Want and edition matches\n");
#endif
            } else {
#ifdef _debugPrints
              printf(" - Found Want, but not scoring because edition doesn't match.\n  - Host Edition:");
              print_item(edition);
              printf("\n  - found Edition: ");
              print_item(shit.joker.edition);
              printf("\n\n");
#endif
            }
          }
        }
        else if (config->Wants[x].value == shit.value) {
          // Check value of non-Joker items
#ifdef _debugPrints
          printf("Found Want %d: Item %d (name: ", x, shit.value);
          print_item(shit.value);
          printf(") in ante %d\n", ante);
#endif
          ScoreWants[x]++;
        }
      }
    } // Done scoring collection of cards

    // Check per-need ante requirements at the end of each ante
    for (int n = 0; n < config->numNeeds; n++) {
      // If this need's desireByAnte is the current ante, check if it's been found
      if (ante == config->Needs[n].desireByAnte && !ScoreNeeds[n]) {
        // We've reached the ante deadline for this need and it's not been found
#ifdef _debugPrints
        printf("Returning invalid result because need %d not found by its required ante %d\n", 
               n, config->Needs[n].desireByAnte);
        print_item(config->Needs[n].value);
        printf("\n");
#endif
        result.valid = false;
        return result;
      }
    }
  } // End of ante loop

  // Calculate final score
  result.TotalScore = 0;
  int totalNeeds = 0;
  for (int n = 0; n < config->numNeeds; n++) {
    if (ScoreNeeds[n] == true) {
      totalNeeds++;
      result.TotalScore ++;
#ifdef _debugPrints
      printf("Need %d was satisfied\n", n);
#endif
    }
  }
  
  // Add bonus points for wants
  for (int w = 0; w < config->numWants; w++) {
    result.ScoreWants[w] = ScoreWants[w];
    // 1 point if this want was ever found (helps weigh it)
    result.TotalScore += ScoreWants[w] > 0 ? 1 : 0;
  }
  
  result.valid = true;
#ifdef _debugPrints
  printf("VALID RESULT - TotalScore = %d (from %i needs)\n", result.TotalScore, totalNeeds);
#endif

  return result;
}
