#include "lib/ouija.cl"

/*
 * ANAGLYPH DECK STRATEGY FILTER - OUIJA EDITION
 * 
 * This filter implements the sophisticated negative tag "freebie zone" strategy for Anaglyph deck:
 * 
 * CORE STRATEGY:
 * - Score NEEDS normally (these are requirements regardless)
 * - Score WANTS only during "freebie zones" when negative tags are active
 * - "Freebie zone" = when you have negative tags that will turn shop jokers negative (free!)
 * 
 * NEGATIVE TAG MECHANICS:
 * - Negative tag only affects NEXT No_Edition joker in shop
 * - First 2 shop items immune to first-slot negative tags (appear before tag button)
 * - Double tags convert to negative tags when you skip for negative
 * - Anaglyph deck gets +1 double tag per ante
 * 
 * TIMING SCENARIOS:
 * - Big Blind Negative: Affects next ante shop items 2+ (skip first 2)
 * - Small Blind Negative: Can reroll from item 2+ (items 0-1 immune)
 * 
 * The config represents: "I need these items always, but show me wants only in freebie zones!"
 */

void ouija_filter(instance *inst, __constant OuijaConfig *config, __global OuijaResult *result) {
  
  // Use faster primitive initialization
  bool valid = true;
  
  // Initialize result struct efficiently
  result->TotalScore = 1;
  result->NegativeJokers = 0;
  
  // Host already clears the entire buffer with clEnqueueFillBuffer - no need to clear arrays in kernel

  // Clamp numNeeds and numWants defensively
  int clampedNumNeeds = config->numNeeds;
  int clampedNumWants = config->numWants;
  if (clampedNumNeeds > MAX_DESIRES_KERNEL) clampedNumNeeds = MAX_DESIRES_KERNEL;
  if (clampedNumNeeds < 0) clampedNumNeeds = 0;
  if (clampedNumWants > MAX_DESIRES_KERNEL) clampedNumWants = MAX_DESIRES_KERNEL;
  if (clampedNumWants < 0) clampedNumWants = 0;

  set_deck(inst, config->deck);
  set_stake(inst, config->stake);
  init_locks(inst, 1, false, true);

  bool ScoreNeeds[MAX_DESIRES_KERNEL] = {false};
  int maxSearchAnte = config->maxSearchAnte;
  item previousTag = RETRY; // Big blind tag from previous ante
  int totalDoubleTags = 0; // Track accumulated double tags

  for (int ante = 1; ante <= maxSearchAnte && valid; ante++) {
    init_unlocks(inst, ante, false);
    
    // Anaglyph deck gets +1 free double tag per ante!
    if (config->deck == Anaglyph_Deck) {
      totalDoubleTags++;
    }
    
    item voucher = next_voucher(inst, ante);
    if (ante > 1 && voucher != Hieroglyph && voucher != Petroglyph) {
      activate_voucher(inst, voucher);
    }
    
    item smallBlindTag = next_tag(inst, ante);
    
    // Count double tags and convert them when we skip for negative
    if (smallBlindTag == Double_Tag) {
      totalDoubleTags++;
    }

    // Check if this ante has any negative tag - EARLY detection for freebie zone
    bool hasFirstSlotNegativeTag = (smallBlindTag == Negative_Tag);
    bool hasEndBlindNegativeTag = (previousTag == Negative_Tag); // From previous ante's big blind
    bool anteHasNegativeTag = (hasFirstSlotNegativeTag || hasEndBlindNegativeTag);
    
    // Calculate how many negative tags we'll have after skipping (1 + all double tags)
    int negativeMultiplier = anteHasNegativeTag ? (1 + totalDoubleTags) : 0;
    
    // Always score needs (these are requirements)
    for (int x = 0; x < clampedNumNeeds; x++) {
      bool isSmallBlind = (config->Needs[x].value == smallBlindTag);
      bool isVoucher = (config->Needs[x].value == voucher);
      ScoreNeeds[x] |= (isSmallBlind | isVoucher);
    }
    
    // ONLY score wants when this ante has a negative tag (freebie zone!)
    if (anteHasNegativeTag) {
      for (int x = 0; x < clampedNumWants; x++) {
        int isSmallBlind = (config->Wants[x].value == smallBlindTag);
        int isVoucher = (config->Wants[x].value == voucher);
        result->ScoreWants[x] += (isSmallBlind + isVoucher);
      }
    }
    
    int shCount = (ante == 1) ? 4 : ante*4;
    
    // FREEBIE ZONE LOGIC: Only process shop for wants when negative tags are active
    if (anteHasNegativeTag) {
      // Determine which shop items can be affected by negative tags
      int firstScorableItem = hasFirstSlotNegativeTag ? 2 : 0; // First slot tags can't affect items 0-1
      int maxNegativeJokers = negativeMultiplier; // How many jokers can be turned negative
      int negativeJokersFound = 0;
      
      // Process shop items
      for (int sh = 0; sh < shCount; sh++) {
        shopitem shItem = next_shop_item(inst, ante);
        if (shItem.value == RETRY) continue;
        if (shItem.value == Showman) inst->params.showman = true;
        
        // Count negative jokers regardless
        result->NegativeJokers += (shItem.type == ItemType_Joker && shItem.joker.edition == Negative);
        
        // ALWAYS score needs (these are requirements)
        for (int x = 0; x < clampedNumNeeds; x++) {
          bool jokerMatch = (config->Needs[x].jokeredition != RETRY) && 
                            (shItem.type == ItemType_Joker) && 
                            (config->Needs[x].value == shItem.value) && 
                            ((config->Needs[x].jokeredition == No_Edition) || 
                             (config->Needs[x].jokeredition == shItem.joker.edition));
          bool regularMatch = (shItem.type != ItemType_Joker && config->Needs[x].value == shItem.value);
          ScoreNeeds[x] |= (jokerMatch | regularMatch);
        }
          // ONLY score wants if this item can be turned negative AND we haven't hit the limit
        bool canBeNegated = (sh >= firstScorableItem) && 
                           (shItem.type == ItemType_Joker) && 
                           (shItem.joker.edition == No_Edition) && 
                           (negativeJokersFound < maxNegativeJokers);
        
        if (canBeNegated) {
          bool foundMatch = false;
          for (int x = 0; x < clampedNumWants; x++) {
            bool jokerMatch = (config->Wants[x].jokeredition != RETRY) && 
                             (config->Wants[x].value == shItem.value) && 
                             ((config->Wants[x].jokeredition == No_Edition) || 
                              (config->Wants[x].jokeredition == Negative)); // Allow negative edition too
            
            if (jokerMatch) {
              result->ScoreWants[x] += (result->ScoreWants[x] == 0 || inst->params.showman == true) ? 1 : 0;
              foundMatch = true;
            }
          }
          // Only increment counter if we found a match and would use a negative tag
          if (foundMatch) {
            negativeJokersFound++;
          }
        }
      }
    } else {
      // No negative tag - still process shop for needs but skip wants entirely
      for (int sh = 0; sh < shCount; sh++) {
        shopitem shItem = next_shop_item(inst, ante);
        if (shItem.value == RETRY) continue;
        if (shItem.value == Showman) inst->params.showman = true;
        
        result->NegativeJokers += (shItem.type == ItemType_Joker && shItem.joker.edition == Negative);
        
        // ALWAYS score needs
        for (int x = 0; x < clampedNumNeeds; x++) {
          bool jokerMatch = (config->Needs[x].jokeredition != RETRY) && 
                            (shItem.type == ItemType_Joker) && 
                            (config->Needs[x].value == shItem.value) && 
                            ((config->Needs[x].jokeredition == No_Edition) || 
                             (config->Needs[x].jokeredition == shItem.joker.edition));
          bool regularMatch = (shItem.type != ItemType_Joker && config->Needs[x].value == shItem.value);
          ScoreNeeds[x] |= (jokerMatch | regularMatch);
        }
        // NO want scoring when no negative tag!
      }
    }
    
    // Process packs
    int packChecks = (ante == 1) ? 4 : 6;
    for (int p = 0; p < packChecks; p++) {
      pack _pack = pack_info(next_pack(inst, ante));
      if (_pack.type == Arcana_Pack) {
        item tarotCards[5] = {RETRY, RETRY, RETRY, RETRY, RETRY};
        arcana_pack(tarotCards, _pack.size, inst, ante);
        for (int t = 0; t < _pack.size; t++) {
          if (tarotCards[t] == RETRY) continue;
          if (tarotCards[t] == The_Soul) {
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
            // ONLY score wants when this ante has a negative tag (freebie zone!)
            if (anteHasNegativeTag) {
              for (int x = 0; x < clampedNumWants; x++) {
                int soulMatch = (config->Wants[x].value == The_Soul);
                int jokerMatch = (config->Wants[x].jokeredition != RETRY) && 
                                 (config->Wants[x].value == soulJoker.joker) && 
                                 ((config->Wants[x].jokeredition == No_Edition) || 
                                  (config->Wants[x].jokeredition == soulJoker.edition));
                result->ScoreWants[x] += (soulMatch + jokerMatch);
              }
            }
          } else {
            for (int x = 0; x < clampedNumNeeds; x++) {
              bool matched = (config->Needs[x].value == tarotCards[t]);
              ScoreNeeds[x] |= matched;
            }
            // ONLY score wants when this ante has a negative tag (freebie zone!)
            if (anteHasNegativeTag) {
              for (int x = 0; x < clampedNumWants; x++) {
                result->ScoreWants[x] += (config->Wants[x].value == tarotCards[t]);
              }
            }
          }
        }
      } else if (_pack.type == Spectral_Pack) {
        item spectralCards[5] = {RETRY, RETRY, RETRY, RETRY, RETRY};
        spectral_pack(spectralCards, _pack.size, inst, ante);
        for (int t = 0; t < _pack.size; t++) {
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
            // ONLY score wants when this ante has a negative tag (freebie zone!)
            if (anteHasNegativeTag) {
              for (int x = 0; x < clampedNumWants; x++) {
                int soulMatch = (config->Wants[x].value == The_Soul);
                int jokerMatch = (config->Wants[x].jokeredition != RETRY) && 
                                 (config->Wants[x].value == soulJoker.joker) && 
                                 ((config->Wants[x].jokeredition == No_Edition) || 
                                  (config->Wants[x].jokeredition == soulJoker.edition));
                result->ScoreWants[x] += (soulMatch + jokerMatch);
              }
            }
          } else {
            for (int x = 0; x < clampedNumNeeds; x++) {
              ScoreNeeds[x] |= (config->Needs[x].value == spectralCards[t]);
            }
            // ONLY score wants when this ante has a negative tag (freebie zone!)
            if (anteHasNegativeTag) {
              for (int x = 0; x < clampedNumWants; x++) {
                result->ScoreWants[x] += (config->Wants[x].value == spectralCards[t]);
              }
            }
          }
        }
      } else if (_pack.type == Buffoon_Pack) {
        jokerdata buffoonJokers[5];
        buffoon_pack_detailed(buffoonJokers, _pack.size, inst, ante);
        for (int t = 0; t < _pack.size; t++) {
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
          // ONLY score wants when this ante has a negative tag (freebie zone!)
          if (anteHasNegativeTag) {
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
    }

    // Get big blind tag for next ante
    previousTag = next_tag(inst, ante);
    
    // Count double tags from big blind too
    if (previousTag == Double_Tag) {
      totalDoubleTags++;
    }

    // Check per-need ante requirements at the end of each ante
    for (int n = 0; n < clampedNumNeeds; n++) {
      bool needNotMetByRequiredAnte = (ante == config->Needs[n].desireByAnte) && ScoreNeeds[n] == false;
      
      if (needNotMetByRequiredAnte) {
        valid = false;
        break;
      }
    }
  } // End of ante loop
  // Calculate total score efficiently only if valid
  if (valid) {
    // Efficiently calculate score from wants
    int wants_score = 0;
    #pragma unroll 4 // Specify unroll factor for better optimization
    for (int w = 0; w < clampedNumWants; w++) {
      // Combine operations to reduce branches
      wants_score += (result->ScoreWants[w] > 0) + result->ScoreWants[w];
    }
    
    result->TotalScore += wants_score;
    result->TotalScore += result->NegativeJokers;
    result->TotalScore += totalDoubleTags;
    
    text s_str = s_to_string(&inst->seed);
    
    // Use efficient copying
    #pragma unroll
    for (int i = 0; i < 9; i++) {
      result->seed[i] = s_str.str[i];
    }
  } else {
    // Invalid seed gets zero score
    result->TotalScore = 0;
  }

  return;
}
