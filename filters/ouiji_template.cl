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

  // Initialize result with default values
  OuijiResult result;
  // Start with score of 0 (invalid until all needs are met)
  result.TotalScore = 0;
  result.NegativeJokers = 0;
  
  // Initialize all need scores to false and want scores to 0 directly in a vectorized way
  bool ScoreNeeds[MAX_DESIRES_KERNEL];
  for (int i = 0; i < config->numNeeds; i++) {
    ScoreNeeds[i] = false;
  }
  
  for (int i = 0; i < config->numWants; i++) {
    result.ScoreWants[i] = 0;
  }

  bool showman_active = false;

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

    // Process vouchers and tags for needs with branchless operations
    for (int x = 0; x < config->numNeeds; x++) {
      bool isSmallBlind = (config->Needs[x].value == smallBlindTag);
      bool isBigBlind = (config->Needs[x].value == bigBlindTag);
      bool isVoucher = (config->Needs[x].value == voucher);
      ScoreNeeds[x] |= (isSmallBlind | isBigBlind | isVoucher);
    }

    // Process vouchers and tags for wants with branchless operations
    for (int x = 0; x < config->numWants; x++) {
      int isSmallBlind = (config->Wants[x].value == smallBlindTag);
      int isBigBlind = (config->Wants[x].value == bigBlindTag);
      int isVoucher = (config->Wants[x].value == voucher);
      result.ScoreWants[x] += (isSmallBlind + isBigBlind + isVoucher);
    }

    // Process shop items using direct scoring
    int shCount = (ante == 1) ? 4 : ((ante >= 8) ? 10 : 6);
    for (int sh = 0; sh < shCount; sh++) {
      shopitem shItem = next_shop_item(inst, ante);
      if (shItem.value == RETRY) continue;
      
#ifdef _debugPrints
      printf("Shop item %d: ", sh);
      print_item(shItem.value);
      if (shItem.type == ItemType_Joker) {
        printf(" (Edition ID: %d)", shItem.joker.edition);
      }
      printf("\n");
#endif

      // Update showman_active flag (optimization: single assignment)
      showman_active |= (shItem.value == Showman);
      
      // Count negative jokers with branchless operation
      result.NegativeJokers += (shItem.type == ItemType_Joker && shItem.joker.edition == Negative);
      
      // Score needs
      for (int x = 0; x < config->numNeeds; x++) {
        // For jokers with edition check
        bool jokerMatch = (config->Needs[x].jokeredition != RETRY) && 
                          (shItem.type == ItemType_Joker) && 
                          (config->Needs[x].value == shItem.value) && 
                          ((config->Needs[x].jokeredition == No_Edition) || 
                           (config->Needs[x].jokeredition == shItem.joker.edition));
        
        // For regular items (non-jokers)
        bool regularMatch = (config->Needs[x].value == shItem.value);
        
        bool matched = (jokerMatch | regularMatch);
        ScoreNeeds[x] |= matched;
        
        // Debug print when we match a need
      #ifdef _debugPrints
        if (matched) {
          printf("Need %d matched in ante %d\n", x, ante);
        }
      #endif
      }
      
      // Score wants - directly use result.ScoreWants array
      for (int x = 0; x < config->numWants; x++) {
        // For jokers with edition check
        int jokerMatch = (config->Wants[x].jokeredition != RETRY) && 
                         (shItem.type == ItemType_Joker) && 
                         (config->Wants[x].value == shItem.value) && 
                         ((config->Wants[x].jokeredition == No_Edition) || 
                          (config->Wants[x].jokeredition == shItem.joker.edition));
                          
        // For regular items (non-jokers)
        int regularMatch = (config->Wants[x].value == shItem.value);
        
        result.ScoreWants[x] += (jokerMatch + regularMatch);
      }
    }

    // Process packs
    int packChecks = (ante == 1) ? 4 : 6;
#ifdef _debugPrints
    printf("performing %d pack checks for ante %d\n", packChecks, ante);
#endif

    for (int p = 0; p < packChecks; p++) {
      pack _pack = pack_info(next_pack(inst, ante));
      
      // Handle different pack types - optimized for branchless where possible
      if (_pack.type == Arcana_Pack) {
        // Process Arcana cards (tarot cards)
        item tarotCards[5] = {RETRY, RETRY, RETRY, RETRY, RETRY};
        arcana_pack(tarotCards, _pack.size, inst, ante);
        
        for (int t = 0; t < _pack.size; t++) {
          if (tarotCards[t] == RETRY) continue;
          
          // Score needs
          for (int x = 0; x < config->numNeeds; x++) {
            bool matched = (config->Needs[x].value == tarotCards[t]);
            ScoreNeeds[x] |= matched;
          }
          
          // Score wants
          for (int x = 0; x < config->numWants; x++) {
            result.ScoreWants[x] += (config->Wants[x].value == tarotCards[t]);
          }
        }
      } 
      else if (_pack.type == Spectral_Pack) {
        // Process Spectral cards
        item spectralCards[5] = {RETRY, RETRY, RETRY, RETRY, RETRY};
        spectral_pack(spectralCards, _pack.size, inst, ante);
        
        for (int t = 0; t < _pack.size; t++) {
          if (spectralCards[t] == RETRY) continue;
          
          // Special handling for The Soul
          if (spectralCards[t] == The_Soul) {
            jokerdata soulJoker = next_joker_with_info(inst, S_Soul, ante);
            
            // Update showman_active with branchless operation
            showman_active |= (soulJoker.joker == Showman);
            
            // Count negative joker with branchless operation
            result.NegativeJokers += (soulJoker.edition == Negative);
            
            // Score needs for both The_Soul itself and the created joker
            for (int x = 0; x < config->numNeeds; x++) {
              bool soulMatch = (config->Needs[x].value == The_Soul);
              bool jokerMatch = (config->Needs[x].jokeredition != RETRY) && 
                                (config->Needs[x].value == soulJoker.joker) && 
                                ((config->Needs[x].jokeredition == No_Edition) || 
                                 (config->Needs[x].jokeredition == soulJoker.edition));
              
              ScoreNeeds[x] |= (soulMatch | jokerMatch);
            }
            
            // Score wants for both The_Soul itself and the created joker
            for (int x = 0; x < config->numWants; x++) {
              int soulMatch = (config->Wants[x].value == The_Soul);
              int jokerMatch = (config->Wants[x].jokeredition != RETRY) && 
                               (config->Wants[x].value == soulJoker.joker) && 
                               ((config->Wants[x].jokeredition == No_Edition) || 
                                (config->Wants[x].jokeredition == soulJoker.edition));
              
              result.ScoreWants[x] += (soulMatch + jokerMatch);
            }
          } 
          else {
            // Regular spectral card
            for (int x = 0; x < config->numNeeds; x++) {
              ScoreNeeds[x] |= (config->Needs[x].value == spectralCards[t]);
            }
            
            for (int x = 0; x < config->numWants; x++) {
              result.ScoreWants[x] += (config->Wants[x].value == spectralCards[t]);
            }
          }
        }
      } 
      else if (_pack.type == Buffoon_Pack) {
        // Process Buffoon pack (jokers)
        jokerdata buffoonJokers[5];
        buffoon_pack_detailed(buffoonJokers, _pack.size, inst, ante);
        
        for (int t = 0; t < _pack.size; t++) {
          if (buffoonJokers[t].joker == RETRY) continue;
          
          // Update showman_active and count negative jokers with branchless operations
          showman_active |= (buffoonJokers[t].joker == Showman);
          result.NegativeJokers += (buffoonJokers[t].edition == Negative);
          
          // Score needs
          for (int x = 0; x < config->numNeeds; x++) {
            bool jokerMatch = (config->Needs[x].jokeredition != RETRY) && 
                              (config->Needs[x].value == buffoonJokers[t].joker) && 
                              ((config->Needs[x].jokeredition == No_Edition) || 
                               (config->Needs[x].jokeredition == buffoonJokers[t].edition));
            
            ScoreNeeds[x] |= jokerMatch;
          }
          
          // Score wants
          for (int x = 0; x < config->numWants; x++) {
            int jokerMatch = (config->Wants[x].jokeredition != RETRY) && 
                             (config->Wants[x].value == buffoonJokers[t].joker) && 
                             ((config->Wants[x].jokeredition == No_Edition) || 
                              (config->Wants[x].jokeredition == buffoonJokers[t].edition));
            
            result.ScoreWants[x] += jokerMatch;
          }
        }
      }
    }

    // Check per-need ante requirements at the end of each ante
    for (int n = 0; n < config->numNeeds; n++) {
      bool needNotMetByRequiredAnte = (ante == config->Needs[n].desireByAnte) && !ScoreNeeds[n];
      
      // Debug output for needs validation
    #ifdef _debugPrints
      if (ante == config->Needs[n].desireByAnte) {
        printf("Checking need %d at ante %d: needed=%d, found=%d\n", 
               n, ante, config->Needs[n].desireByAnte, ScoreNeeds[n]);
      }
    #endif

      // If a need isn't met by its required ante, set score to 0 (invalid)
      if (needNotMetByRequiredAnte) {
      #ifdef _debugPrints    
        printf("Returning invalid result because need %d not found by its required ante %d\n", n, config->Needs[n].desireByAnte);
        print_item(config->Needs[n].value);
        printf("\n");
      #endif
        result.TotalScore = 0;
        return result;
      }
    }
  } // End of ante loop

  // If all needs were met, ensure score is at least 1 (valid)
  // Base value of 1 indicates "valid" (all needs met)
  result.TotalScore = 1;
  
  // Add final debug output to see the score before return
  //printf("Final score before bonus: %d\n", result.TotalScore);
  
  // Add bonus points for wants that were found (10 points each)
  for (int w = 0; w < config->numWants && w < MAX_DESIRES_KERNEL; w++) {
    // Branchless way to add 2 points if want was found (ScoreWants > 0)
    result.TotalScore += (result.ScoreWants[w] > 0) * 1;
    result.TotalScore += result.ScoreWants[w];
  }

  // Add bonus points for negative jokers
  result.TotalScore += result.NegativeJokers;

  // Copy the seed to the result
  text s_str = s_to_string(&inst->seed);
  for (int i = 0; i < 9; i++) {
    result.seed[i] = s_str.str[i];
  }

  //printf("Final score after bonus: %d\n", result.TotalScore);
  return result;
}
