#include "lib/ouija.cl"

/*
 * ANAGLYPH DECK STRATEGY FILTER - PERFECTED IMPLEMENTATION
 *
 * Core Anaglyph strategy mechanics:
 * - Negative jokers don't consume joker slots (key strategy)
 * - Negative tag creates N applications (1 + double_tags_accumulated)
 * - Only No_Edition jokers consume negative tag applications
 * - Score wants in both packs AND shops with proper slot management
 * - Track joker slots: 5 base + voucher effects
 * - Showman duplicate rule handling
 * - Anaglyph deck gets +1 double tag per ante
 */

// Helper function to check if we can take a joker
bool can_take_joker(jokerdata joker, int filledSlots, int jokerSlots,
                    int *negativeTagApplications) {
  // Negative edition jokers never consume slots
  if (joker.edition == Negative) {
    return true;
  }

  // If we have negative tag applications and joker is No_Edition, consume one
  if (*negativeTagApplications > 0 && joker.edition == No_Edition) {
    (*negativeTagApplications)--;
    return true; // Doesn't consume physical slot
  }

  // Otherwise, need physical slot space
  return filledSlots < jokerSlots;
}

// Helper function to handle slot consumption for regular jokers
void consume_slot_if_needed(jokerdata joker, int *filledSlots, int jokerSlots,
                            int negativeTagApplications) {
  // Only consume slot if:
  // 1. Not negative edition
  // 2. Not using negative tag application (checked in can_take_joker)
  // 3. Have space
  if (joker.edition != Negative && negativeTagApplications == 0 &&
      *filledSlots < jokerSlots) {
    (*filledSlots)++;
  }
}

// Helper function to handle The Soul card processing
void handle_the_soul(instance *inst, int ante, __constant OuijaConfig *config,
                     __global OuijaResult *result, bool *ScoreNeeds,
                     int *filledSlots, int jokerSlots, int clampedNumNeeds,
                     int clampedNumWants, int *negativeTagApplications) {
  jokerdata soulJoker = next_joker_with_info(inst, S_Soul, ante);
  result->NegativeJokers += (soulJoker.edition == Negative);

  if (soulJoker.joker == Showman) {
    inst->params.showman = true;
  }

  // Score needs for Soul and the joker it creates
  for (int x = 0; x < clampedNumNeeds; x++) {
    bool soulMatch = (config->Needs[x].value == The_Soul);
    bool jokerMatch = (config->Needs[x].jokeredition != RETRY) &&
                      (config->Needs[x].value == soulJoker.joker) &&
                      ((config->Needs[x].jokeredition == No_Edition) ||
                       (config->Needs[x].jokeredition == soulJoker.edition));
    if (soulMatch || jokerMatch) {
      ScoreNeeds[x] = true;
      // Handle slot consumption for the joker created by Soul
      if (soulJoker.joker != RETRY) {
        consume_slot_if_needed(soulJoker, filledSlots, jokerSlots,
                               *negativeTagApplications);
      }
    }
  }

  // Score wants for Soul and the joker it creates
  for (int x = 0; x < clampedNumWants; x++) {
    bool soulMatch = (config->Wants[x].value == The_Soul);
    bool jokerMatch = (config->Wants[x].jokeredition != RETRY) &&
                      (config->Wants[x].value == soulJoker.joker) &&
                      ((config->Wants[x].jokeredition == No_Edition) ||
                       (config->Wants[x].jokeredition == soulJoker.edition));
    if (soulMatch || jokerMatch) {
      // Can we take this joker?
      if (can_take_joker(soulJoker, *filledSlots, jokerSlots,
                         negativeTagApplications)) {
        result->ScoreWants[x] += 1;
        // Consume slot if needed (handles negative tag consumption internally)
        if (soulJoker.joker != RETRY) {
          consume_slot_if_needed(soulJoker, filledSlots, jokerSlots,
                                 *negativeTagApplications);
        }
      }
    }
  }
}

void ouija_filter(instance *inst, __constant OuijaConfig *config,
                  __global OuijaResult *result) {

  bool valid = true;
  // Initialize result struct
  result->TotalScore = 1;
  result->NegativeJokers = 0;

  // Initialize ScoreWants array
  for (int i = 0; i < MAX_DESIRES_KERNEL; i++) {
    result->ScoreWants[i] = 0;
  }

  // Clamp parameters
  int clampedNumNeeds = min(max(config->numNeeds, 0), MAX_DESIRES_KERNEL);
  int clampedNumWants = min(max(config->numWants, 0), MAX_DESIRES_KERNEL);

  set_deck(inst, config->deck);
  set_stake(inst, config->stake);
  init_locks(inst, 1, false, true);
  bool ScoreNeeds[MAX_DESIRES_KERNEL] = {false};
  int maxSearchAnte = config->maxSearchAnte;
  int totalDoubleTags = 0;

  // Joker slot management
  int jokerSlots = 5;  // Start with 5 joker slots
  int filledSlots = 0; // Track how many slots are filled

  // Negative tag tracking
  int negativeTagApplications = 0; // Available negative tag applications

  for (int ante = 1; ante <= maxSearchAnte && valid; ante++) {
    init_unlocks(inst, ante, false);

    // Handle voucher and its effects on joker slots
    item voucher = next_voucher(inst, ante);
    if (ante > 1 && voucher != Hieroglyph && voucher != Petroglyph) {
      activate_voucher(inst, voucher);

      if (voucher == Antimatter) {
         jokerSlots++; // Blank gives +1 joker slot
      }
    }


    item smallBlindTag = next_tag(inst, ante);
    if (ante > 1 && smallBlindTag != Negative_Tag) continue;

    // Check if negative tag is triggered and calculate applications
    if (smallBlindTag == Negative_Tag) {
      // Search wants for the first tag no matter what kind it is:
      for (int x = 0; x < clampedNumWants; x++) {
        if (config->Wants[x].value == Negative_Tag) {
          result->ScoreWants[x] += 1;
        }
      }
      // Negative tag gives 1 + totalDoubleTags applications
      negativeTagApplications = 1 + totalDoubleTags;
    }

    // Count double tags
    if (smallBlindTag == Double_Tag) {
      totalDoubleTags++;
    }

    // Score needs for tags and vouchers
    for (int x = 0; x < clampedNumNeeds; x++) {
      bool isSmallBlind = (config->Needs[x].value == smallBlindTag);
      bool isVoucher = (config->Needs[x].value == voucher);
      ScoreNeeds[x] |= (isSmallBlind | isVoucher);
    }

    // Score wants for tags and vouchers
    for (int x = 0; x < clampedNumWants; x++) {
      bool isSmallBlind = (config->Wants[x].value == smallBlindTag);
      bool isVoucher = (config->Wants[x].value == voucher);
      if (isSmallBlind || isVoucher) {
        // Check Showman duplicate rule
        bool showmanAllows =
            (result->ScoreWants[x] == 0) || inst->params.showman;
        if (showmanAllows) {
          result->ScoreWants[x] += 1;
        }
      }
    }

    // Process packs
    int packChecks = (ante == 1) ? 4 : 20;
    for (int p = 0; p < packChecks; p++) {
      pack _pack = pack_info(next_pack(inst, ante));

      if (_pack.type == Arcana_Pack) {
        item tarotCards[5] = {RETRY, RETRY, RETRY, RETRY, RETRY};
        arcana_pack(tarotCards, _pack.size, inst, ante);

        for (int t = 0; t < _pack.size; t++) {
          if (tarotCards[t] == RETRY)
            continue;

          if (tarotCards[t] == The_Soul) {
            handle_the_soul(inst, ante, config, result, ScoreNeeds,
                            &filledSlots, jokerSlots, clampedNumNeeds,
                            clampedNumWants, &negativeTagApplications);
          } else {
            // Score needs and wants for tarot cards
            for (int x = 0; x < clampedNumNeeds; x++) {
              if (config->Needs[x].value == tarotCards[t]) {
                ScoreNeeds[x] = true;
              }
            }
            for (int x = 0; x < clampedNumWants; x++) {
              if (config->Wants[x].value == tarotCards[t]) {
                result->ScoreWants[x] += 1;
              }
            }
          }
        }
      } else if (_pack.type == Spectral_Pack) {
        item spectralCards[5] = {RETRY, RETRY, RETRY, RETRY, RETRY};
        spectral_pack(spectralCards, _pack.size, inst, ante);

        for (int t = 0; t < _pack.size; t++) {
          if (spectralCards[t] == RETRY)
            continue;

          if (spectralCards[t] == The_Soul) {
            handle_the_soul(inst, ante, config, result, ScoreNeeds,
                            &filledSlots, jokerSlots, clampedNumNeeds,
                            clampedNumWants, &negativeTagApplications);
          } else {
            // Score needs and wants for other spectral cards
            for (int x = 0; x < clampedNumNeeds; x++) {
              if (config->Needs[x].value == spectralCards[t]) {
                ScoreNeeds[x] = true;
              }
            }
            for (int x = 0; x < clampedNumWants; x++) {
              if (config->Wants[x].value == spectralCards[t]) {
                result->ScoreWants[x] += 1;
              }
            }
          }
        }
      } else if (_pack.type == Buffoon_Pack) {
        jokerdata buffoonJokers[5];
        buffoon_pack_detailed(buffoonJokers, _pack.size, inst, ante);

        for (int t = 0; t < _pack.size; t++) {
          if (buffoonJokers[t].joker == RETRY)
            continue;

          if (buffoonJokers[t].joker == Showman) {
            inst->params.showman = true;
          }

          result->NegativeJokers += (buffoonJokers[t].edition == Negative);

          // Score needs for jokers
          for (int x = 0; x < clampedNumNeeds; x++) {
            bool jokerMatch =
                (config->Needs[x].jokeredition != RETRY) &&
                (config->Needs[x].value == buffoonJokers[t].joker) &&
                ((config->Needs[x].jokeredition == No_Edition) ||
                 (config->Needs[x].jokeredition == buffoonJokers[t].edition));
            if (jokerMatch) {
              ScoreNeeds[x] = true;
              // Handle slot consumption for needs
              consume_slot_if_needed(buffoonJokers[t], &filledSlots, jokerSlots,
                                     negativeTagApplications);
            }
          }

          // Score wants for jokers with proper slot management
          for (int x = 0; x < clampedNumWants; x++) {
            bool jokerMatch =
                (config->Wants[x].jokeredition != RETRY) &&
                (config->Wants[x].value == buffoonJokers[t].joker) &&
                ((config->Wants[x].jokeredition == No_Edition) ||
                 (config->Wants[x].jokeredition == buffoonJokers[t].edition));
            if (jokerMatch) {
              // Can we take this joker?
              if (can_take_joker(buffoonJokers[t], filledSlots, jokerSlots,
                                 &negativeTagApplications)) {
                result->ScoreWants[x] += 1;
                // Consume slot if needed (handles negative tag consumption
                // internally)
                consume_slot_if_needed(buffoonJokers[t], &filledSlots,
                                       jokerSlots, negativeTagApplications);
              }
            }
          }
        }
      }
    }

    // Process shop items
    int shCount = (ante == 1) ? 4 : 8;
    for (int sh = 0; sh < shCount; sh++) {
      shopitem shItem = next_shop_item(inst, ante);
      if (shItem.value == RETRY)
        continue;

      if (shItem.value == Showman) {
        inst->params.showman = true;
      }

      if (shItem.type == ItemType_Joker) {
        result->NegativeJokers += (shItem.joker.edition == Negative);
      }

      // Score needs from shop
      for (int x = 0; x < clampedNumNeeds; x++) {
        bool jokerMatch =
            (shItem.type == ItemType_Joker) &&
            (config->Needs[x].jokeredition != RETRY) &&
            (config->Needs[x].value == shItem.joker.joker) &&
            ((config->Needs[x].jokeredition == No_Edition) ||
             (config->Needs[x].jokeredition == shItem.joker.edition));
        bool regularMatch = (config->Needs[x].value == shItem.value);

        if (jokerMatch || regularMatch) {
          ScoreNeeds[x] = true;
          // Handle slot consumption for needs
          if (shItem.type == ItemType_Joker) {
            consume_slot_if_needed(shItem.joker, &filledSlots, jokerSlots,
                                   negativeTagApplications);
          }
        }
      }

      // Score wants from shop with proper slot management
      for (int x = 0; x < clampedNumWants; x++) {
        bool jokerMatch =
            (shItem.type == ItemType_Joker) &&
            (config->Wants[x].jokeredition != RETRY) &&
            (config->Wants[x].value == shItem.joker.joker) &&
            ((config->Wants[x].jokeredition == No_Edition) ||
             (config->Wants[x].jokeredition == shItem.joker.edition));
        bool regularMatch = (config->Wants[x].value == shItem.value);

        if (jokerMatch || regularMatch) {
          // Check Showman duplicate rule
          bool showmanAllows =
              (result->ScoreWants[x] == 0) || inst->params.showman;

          if (showmanAllows) {
            // For jokers, check if we can take them
            if (shItem.type == ItemType_Joker) {
              if (can_take_joker(shItem.joker, filledSlots, jokerSlots,
                                 &negativeTagApplications)) {
                result->ScoreWants[x] += 1;
                // Consume slot if needed
                consume_slot_if_needed(shItem.joker, &filledSlots, jokerSlots,
                                       negativeTagApplications);
              }
            } else {
              // Non-joker items always get scored
              result->ScoreWants[x] += 1;
            }
          }
        }
      }
    }

    // Get big blind tag and store for next ante's transition check
    item bigBlindTag = next_tag(inst, ante);

      // Search wants for the first tag no matter what kind it is:
      for (int x = 0; x < clampedNumWants; x++) {
        if (config->Wants[x].value == Negative_Tag) {
          result->ScoreWants[x] += 1;
        }
      }

      // And Needs
      for (int x = 0; x < clampedNumNeeds; x++) {
        if (config->Needs[x].value == Negative_Tag) {
          ScoreNeeds[x] = true;
        }
      }

    if (bigBlindTag == Double_Tag) {
      totalDoubleTags++;
    }

    // Anaglyph deck gets +1 free double tag after beating each boss blind
    if (config->deck == Anaglyph_Deck) {
      totalDoubleTags++;
    }

    // Check per-need ante requirements
    for (int n = 0; n < clampedNumNeeds; n++) {
      bool needNotMetByRequiredAnte =
          (ante == config->Needs[n].desireByAnte) && ScoreNeeds[n] == false;
      if (needNotMetByRequiredAnte) {
        valid = false;
        break;
      }
    }
  }
  // Calculate final score
  if (valid) {
    int wants_score = 0;
    for (int w = 0; w < clampedNumWants; w++) {
      wants_score += (result->ScoreWants[w] > 0) + result->ScoreWants[w];
    }
    result->TotalScore += wants_score;

    text s_str = s_to_string(&inst->seed);
    for (int i = 0; i < 9; i++) {
      result->seed[i] = s_str.str[i];
    }
  } else {
    result->TotalScore = 0;
  }
}
