#include "lib/ouija.cl"
//#define CACHE_SIZE 800
#define _debugPrintsMAGIC

void ouija_filter(instance *inst, __constant OuijaConfig *config, OuijaResult *result) {

  int gid = get_global_id(0);
  // printf("[Kernel] Kernel start, global_id=%d\n", gid);
  // text debug_Seed = s_to_string(&inst->seed);
  // printf("[Kernel] Seed: [%s]\n", debug_Seed.str);
  bool valid = true;
  result->TotalScore = 1;
  result->NegativeJokers = 0;
  for (int i = 0; i < MAX_DESIRES_KERNEL; i++) {
    result->ScoreWants[i] = 0;
  }
  for (int i = 0; i < 9; i++) {
    result->seed[i] = 0;
  }

  // Clamp numNeeds and numWants defensively
  int clampedNumNeeds = config->numNeeds;
  int clampedNumWants = config->numWants;
  if (clampedNumNeeds > MAX_DESIRES_KERNEL) clampedNumNeeds = MAX_DESIRES_KERNEL;
  if (clampedNumNeeds < 0) clampedNumNeeds = 0;
  if (clampedNumWants > MAX_DESIRES_KERNEL) clampedNumWants = MAX_DESIRES_KERNEL;
  if (clampedNumWants < 0) clampedNumWants = 0;

  // Memory fence


#ifdef _debugPrints
  printf("[Kernel] Starting filter\n");
  printf("[Kernel] Deck id: %d\n", config->deck);
  printf("[Kernel] Stake id: %d\n", config->stake);
  printf("[Kernel] Num Needs: %d (clamped: %d)\n", config->numNeeds, clampedNumNeeds);
  printf("[Kernel] Num Wants: %d (clamped: %d)\n", config->numWants, clampedNumWants);
  printf("[Kernel] Max Search Ante: %d\n", config->maxSearchAnte);
  printf("[Kernel] Seed: [%s]\n", debug_Seed.str);
#endif

  set_deck(inst, config->deck);
  set_stake(inst, config->stake);
  init_locks(inst, 1, false, true);

  int ante = 0;
  bool ScoreNeeds[MAX_DESIRES_KERNEL] = {false};
  int maxSearchAnte = config->maxSearchAnte;

  if (config->deck == Erratic_Deck) {
    item deck[52];
    init_deck(inst, deck);
    int bestScore = 0;
    for (int i = 0; i < 52; i++) {
      item r = rank(deck[i]);
      item s = suit(deck[i]);
      for (int w = 0; w < clampedNumWants; w++) {
        if (r == config->Wants[w].value || s == config->Wants[w].value) {
          result->ScoreWants[w] += 1;
          if (result->ScoreWants[w] > result->TotalScore) {
            result->TotalScore = result->ScoreWants[w];
          }
        }
      }
      for (int n = 0; n < clampedNumNeeds; n++) {
        if (r == config->Needs[n].value || s == config->Needs[n].value) {
          ScoreNeeds[n] = true;
        }
      }
    }
  }

  for (int ante = 1; ante <= maxSearchAnte; ante++) {
    init_unlocks(inst, ante, false);
    item voucher = next_voucher(inst, ante);
#ifdef _debugPrints
    printf("[Kernel] Ante %d Voucher: ", ante);
    print_item(voucher);
    printf("\n");
#endif
    if (ante > 1 && voucher != Hieroglyph && voucher != Petroglyph) {
      activate_voucher(inst, voucher);
    }
    item smallBlindTag = next_tag(inst, ante);
    item bigBlindTag = next_tag(inst, ante);
    for (int x = 0; x < clampedNumNeeds; x++) {
      bool isSmallBlind = (config->Needs[x].value == smallBlindTag);
      bool isBigBlind = (config->Needs[x].value == bigBlindTag);
      bool isVoucher = (config->Needs[x].value == voucher);
      ScoreNeeds[x] |= (isSmallBlind | isBigBlind | isVoucher);
    }
    for (int x = 0; x < clampedNumWants; x++) {
      int isSmallBlind = (config->Wants[x].value == smallBlindTag);
      int isBigBlind = (config->Wants[x].value == bigBlindTag);
      int isVoucher = (config->Wants[x].value == voucher);
      result->ScoreWants[x] += (isSmallBlind + isBigBlind + isVoucher);
    }
    int shCount = (ante == 1) ? 4 : 8;
    for (int sh = 0; sh < shCount; sh++) {
      shopitem shItem = next_shop_item(inst, ante);
      if (shItem.value == RETRY) continue;
#ifdef _debugPrints1
      printf("[Kernel] Shop item %d: ", sh);
      print_item(shItem.value);
      if (shItem.type == ItemType_Joker) {
        printf(" (Edition ID: %d)", shItem.joker.edition);
      }
      printf("\n");
#endif
      if (shItem.value == Showman)
        inst->params.showman = true;
      result->NegativeJokers += (shItem.type == ItemType_Joker && shItem.joker.edition == Negative);
      for (int x = 0; x < clampedNumNeeds; x++) {
        bool jokerMatch = (config->Needs[x].jokeredition != RETRY) && 
                          (shItem.type == ItemType_Joker) && 
                          (config->Needs[x].value == shItem.value) && 
                          ((config->Needs[x].jokeredition == No_Edition) || 
                           (config->Needs[x].jokeredition == shItem.joker.edition));
        bool regularMatch = (shItem.type != ItemType_Joker && config->Needs[x].value == shItem.value);
        bool matched = (jokerMatch | regularMatch);
        ScoreNeeds[x] |= matched;
#ifdef _debugPrints1
        if (matched) {
          printf("[Kernel] Need %d matched in ante %d\n", x, ante);
        }
#endif
      }
      for (int x = 0; x < clampedNumWants; x++) {
        int jokerMatch = (config->Wants[x].jokeredition != RETRY) && 
                         (shItem.type == ItemType_Joker) && 
                         (config->Wants[x].value == shItem.value) && 
                         ((config->Wants[x].jokeredition == No_Edition) || 
                          (config->Wants[x].jokeredition == shItem.joker.edition));
        int regularMatch = (shItem.type != ItemType_Joker && config->Wants[x].value == shItem.value);
        result->ScoreWants[x] += (jokerMatch && (result->ScoreWants[x] == 0 || inst->params.showman == true));
        result->ScoreWants[x] += regularMatch;
      }
    }
    int packChecks = (ante == 1) ? 4 : 6;
#ifdef _debugPrints1
    printf("[Kernel] performing %d pack checks for ante %d\n", packChecks, ante);
#endif
    for (int p = 0; p < packChecks; p++) {
      pack _pack = pack_info(next_pack(inst, ante));
#ifdef _debugPrints1
      printf("[Kernel] Pack %d type:", p);
      print_item(_pack.type);
      printf("\n");
#endif
      if (_pack.type == Arcana_Pack) {
        item tarotCards[5] = {RETRY, RETRY, RETRY, RETRY, RETRY};
        arcana_pack(tarotCards, _pack.size, inst, ante);
        for (int t = 0; t < _pack.size; t++) {
#ifdef _debugPrints1
          printf("[Kernel] Arcana card %d: ", t);
          print_item(tarotCards[t]);
          printf("\n");
#endif
          if (tarotCards[t] == RETRY) continue;
          if (tarotCards[t] == The_Soul) {
            jokerdata soulJoker = next_joker_with_info(inst, S_Soul, ante);
#ifdef _debugPrints1
            printf("[Kernel] The Soul joker: ");
            if (soulJoker.edition != No_Edition) {
              print_item(soulJoker.edition);
            }
            printf(" ");
            print_item(soulJoker.joker);
            printf("\n");
#endif
            result->NegativeJokers += (soulJoker.edition == Negative);
            for (int x = 0; x < clampedNumNeeds; x++) {
#ifdef _debugPrints1
              printf("[Kernel] Checking need %d for The Soul\n", x);
#endif
              bool soulMatch = (config->Needs[x].value == The_Soul);
#ifdef _debugPrints1
              if (soulMatch) {
                printf("[Kernel] Matched The Soul need %d\n", x);
              }
#endif
              bool jokerMatch = (config->Needs[x].jokeredition != RETRY) && 
                                (config->Needs[x].value == soulJoker.joker) && 
                                ((config->Needs[x].jokeredition == No_Edition) || 
                                 (config->Needs[x].jokeredition == soulJoker.edition));
#ifdef _debugPrints1
              if (jokerMatch) {
                printf("[Kernel] Matched joker need %d\n", x);
              } else {
                printf("[Kernel] Did not match joker need %d\n", x);
                printf("[Kernel] Need value: ");
                print_item(config->Needs[x].value);
                printf("\n");
                printf("[Kernel] Joker value: ");
                print_item(soulJoker.joker);
                printf("\n");
                printf("[Kernel] Joker edition: ");
                print_item(soulJoker.edition);
                printf("\n");
                printf("[Kernel] Need joker edition: ");
                print_item(config->Needs[x].jokeredition);
                printf("\n");
              }
#endif
              ScoreNeeds[x] |= (soulMatch | jokerMatch);
            }
            for (int x = 0; x < clampedNumWants; x++) {
              int soulMatch = (config->Wants[x].value == The_Soul);
              int jokerMatch = (config->Wants[x].jokeredition != RETRY) && 
                               (config->Wants[x].value == soulJoker.joker) && 
                               ((config->Wants[x].jokeredition == No_Edition) || 
                                (config->Wants[x].jokeredition == soulJoker.edition));
              result->ScoreWants[x] += (soulMatch + jokerMatch);
            }
          } else {
            for (int x = 0; x < clampedNumNeeds; x++) {
              bool matched = (config->Needs[x].value == tarotCards[t]);
              ScoreNeeds[x] |= matched;
            }
            for (int x = 0; x < clampedNumWants; x++) {
              result->ScoreWants[x] += (config->Wants[x].value == tarotCards[t]);
            }
          }
        }
      } else if (_pack.type == Spectral_Pack) {
        item spectralCards[5] = {RETRY, RETRY, RETRY, RETRY, RETRY};
        spectral_pack(spectralCards, _pack.size, inst, ante);
        for (int t = 0; t < _pack.size; t++) {
#ifdef _debugPrints1
          printf("[Kernel] Spectral card %d: %d\n", t, spectralCards[t]);
#endif
          if (spectralCards[t] == RETRY) continue;
          if (spectralCards[t] == The_Soul) {
            jokerdata soulJoker = next_joker_with_info(inst, S_Soul, ante);
            result->NegativeJokers += (soulJoker.edition == Negative);
            for (int x = 0; x < clampedNumNeeds; x++) {
              bool soulMatch = (config->Needs[x].value == The_Soul);
              bool jokerMatch = (config->Needs[x].jokeredition != RETRY) && 
                                (config->Needs[x].value == soulJoker.joker) && 
                                ((config->Needs[x].jokeredition == No_Edition) || 
                                 (config->Needs[x].jokeredition == soulJoker.edition));
              ScoreNeeds[x] |= (soulMatch | jokerMatch);
            }
            for (int x = 0; x < clampedNumWants; x++) {
              int soulMatch = (config->Wants[x].value == The_Soul);
              int jokerMatch = (config->Wants[x].jokeredition != RETRY) && 
                               (config->Wants[x].value == soulJoker.joker) && 
                               ((config->Wants[x].jokeredition == No_Edition) || 
                                (config->Wants[x].jokeredition == soulJoker.edition));
              result->ScoreWants[x] += (soulMatch + jokerMatch);
            }
          } else {
            for (int x = 0; x < clampedNumNeeds; x++) {
              ScoreNeeds[x] |= (config->Needs[x].value == spectralCards[t]);
            }
            for (int x = 0; x < clampedNumWants; x++) {
              result->ScoreWants[x] += (config->Wants[x].value == spectralCards[t]);
            }
          }
        }
      } else if (_pack.type == Buffoon_Pack) {
        jokerdata buffoonJokers[5];
        buffoon_pack_detailed(buffoonJokers, _pack.size, inst, ante);
        for (int t = 0; t < _pack.size; t++) {
#ifdef _debugPrints1
          printf("[Kernel] Buffoon joker %d: %d\n", t, buffoonJokers[t].joker);
#endif
          if (buffoonJokers[t].joker == RETRY) continue;
          if (buffoonJokers[t].joker == Showman)
            inst->params.showman = true;
          result->NegativeJokers += (buffoonJokers[t].edition == Negative);
          for (int x = 0; x < clampedNumNeeds; x++) {
            bool jokerMatch = (config->Needs[x].jokeredition != RETRY) && 
                              (config->Needs[x].value == buffoonJokers[t].joker) && 
                              ((config->Needs[x].jokeredition == No_Edition) || 
                               (config->Needs[x].jokeredition == buffoonJokers[t].edition));
            ScoreNeeds[x] = ScoreNeeds[x] ? ScoreNeeds[x] : jokerMatch;
          }
          for (int x = 0; x < clampedNumWants; x++) {
            int jokerMatch = (config->Wants[x].jokeredition != RETRY) && 
                             (config->Wants[x].value == buffoonJokers[t].joker) && 
                             ((config->Wants[x].jokeredition == No_Edition) || 
                              (config->Wants[x].jokeredition == buffoonJokers[t].edition));
            result->ScoreWants[x] += jokerMatch && (result->ScoreWants[x] == 0 || inst->params.showman == true);
          }
        }
      }
    }

    // Check per-need ante requirements at the end of each ante
    bool earlyExit = false;
    for (int n = 0; n < clampedNumNeeds && !earlyExit; n++) {
      bool needNotMetByRequiredAnte = (ante == config->Needs[n].desireByAnte) && ScoreNeeds[n] == false;
      
      if (needNotMetByRequiredAnte) {
        // Use memory fence only (no barrier) to avoid workgroup deadlocks
        mem_fence(CLK_GLOBAL_MEM_FENCE); // Ensure memory consistency
        valid = false;
        result->TotalScore = 0;
        earlyExit = true; // Set the flag instead of using break
      }
    }
  } // End of ante loop

  // Ensure all memory operations from the ante loop are completed before proceeding
  mem_fence(CLK_GLOBAL_MEM_FENCE);
  mem_fence(CLK_LOCAL_MEM_FENCE);

  text s_str = s_to_string(&inst->seed);
  for (int i = 0; i < 9; i++) {
    result->seed[i] = s_str.str[i];
  }


  result->TotalScore += 1;

  for (int w = 0; valid && w < clampedNumWants; w++) {
    result->TotalScore += (result->ScoreWants[w] > 0) * 1;
    result->TotalScore += result->ScoreWants[w];
  }

  if (valid)
   result->TotalScore += result->NegativeJokers;
  else
    result->TotalScore = 0;

  // Ensure all memory updates are visible to other workgroups before returning
  mem_fence(CLK_GLOBAL_MEM_FENCE | CLK_LOCAL_MEM_FENCE);
  return;
}
