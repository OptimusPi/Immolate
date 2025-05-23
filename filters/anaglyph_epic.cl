// filepath: x:\Immolate\filters\anaglyph_epic.cl
// Based on template-pi.cl, adapted for Anaglyph deck and negskips logic.
#include "lib/immolate.cl"
#define CACHE_SIZE 128
#define FIXED_FILTER_CUTOFF
// #define _debugPrints 1

// Scoring defines from template-pi.cl
#define _DFirst 100000000
#define _D1 10000000
#define _D2 1000000
#define _D3 100000
#define _D4 10000
#define _D5 1000
#define _D6 100
#define _D7 10
#define _DLast 1

// Function to evaluate Jokers found after a Negative Tag triggers
// Returns a score based on template-pi.cl's Wants/Needs, and updates negJokers
// count. Returns 1 if a desired joker is found (to consume double tags), 0
// otherwise. Updates negJokers directly via pointer.
int evaluateNegativeTagJokerForEpic(instance *inst, int ante, item Needs[],
                                    int NUM_NEEDS, item Wants[], int NUM_WANTS,
                                    int *negJokers) {
  shopitem _item = next_shop_item(inst, ante);
  bool found_target = false;

  // Check the next few slots for an immediate Negative Joker
  for (int i = 0; i < 5; i++) { // Look ahead 5 slots
    if (_item.type == ItemType_Joker && _item.joker.edition == Negative) {
      (*negJokers)++; // Found an inherent Negative Joker
      // Check if it's a Need or Want
      for (int n = 0; n < NUM_NEEDS; n++) {
        if (_item.value == Needs[n]) {
          found_target = true;
          break;
        }
      }
      if (!found_target) {
        for (int w = 0; w < NUM_WANTS; w++) {
          if (_item.value == Wants[w]) {
            found_target = true;
            break;
          }
        }
      }
      // Even if not a Need/Want, finding *any* negative increments negJokers
      // We don't break here, let the next check handle the plain joker
    }
    if (_item.type == ItemType_Joker && _item.joker.edition == No_Edition)
      break; // Found the plain joker the tag will affect
    _item = next_shop_item(inst, ante); // Check next item
  }

  // Evaluate the plain Joker the tag hits
  if (_item.type != ItemType_Joker || _item.joker.edition != No_Edition)
    return 0; // Tag hits nothing useful

  // Check if the tagged joker is a Need or Want
  for (int n = 0; n < NUM_NEEDS; n++) {
    if (_item.value == Needs[n]) {
      found_target = true;
      break;
    }
  }
  if (!found_target) {
    for (int w = 0; w < NUM_WANTS; w++) {
      if (_item.value == Wants[w]) {
        found_target = true;
        break;
      }
    }
  }

  return found_target ? 1
                      : 0; // Return 1 if the tag hit a Need/Want, 0 otherwise
}

long filter(instance *inst) {
#ifdef _debugPrints
  printf("Starting filter\n");
#endif
  set_deck(inst, Anaglyph_Deck); // Use Anaglyph Deck
  set_stake(inst, White_Stake);
  init_locks(inst, 1, false, false);
  inst->params.showman = false; // Initialize showman flag

// BEGIN CONFIG (from template-pi.cl)
#define NUM_NEEDS 4
#define NUM_WANTS 4
#define NEED_BY_ANTE 4         // Adjust as needed
#define WANT_BY_ANTE 9         // Search through ante 8
#define WAIT_FOR_ANTE_PERKEO 2 // Allow Perkeo from ante 1
#define NEED_BY_ANTE_PERKEO 5  // Must find Perkeo by ante 5
  item Needs[NUM_NEEDS] = {Blueprint, Brainstorm, Showman,
                           Perkeo}; // Added Perkeo as a Need
  bool ScoreNeeds[NUM_NEEDS] = {false, false, false, false};
  item Wants[NUM_WANTS] = {Blueprint, Brainstorm, Wee_Joker, Hack}; 
  int ScoreWants[NUM_WANTS] = {0, 0, 0, 0};
  // END CONFIG

  int ScoreDigits[7] = {_D1, _D2, _D3, _D4,
                        _D5, _D6, _D7}; // Keep template-pi scoring structure
  int observatoryAnte = 99;
  int telescopeAnte = 99;
  int perkeoAnte = 99;
  int canioAnte = 99;     // Track Canio ante
  int tribouletAnte = 99; // Track Triboulet ante
  int yorickAnte = 99;    // Track Yorick ante
  int chicotAnte = 99;       // Track Chicot ante

  int negTags = 0;     // Counts successful Negative Tag triggers on Needs/Wants
  int double_tags = 0; // Track accumulated Double Tags (negskips logic)
  bool perkeo = false; // Track if Perkeo is found
  int negJokers =
      0; // Counts inherently negative jokers found (template-pi logic)

  // Search through antes
  int antesToSearch = WANT_BY_ANTE > 8 ? WANT_BY_ANTE : 8; // Use config, max 8
  for (int ante = 1; ante <= antesToSearch; ante++) {

    init_unlocks(inst, ante, false);

    // --- Voucher Checks (from template-pi) ---
    if (telescopeAnte == 99 && next_voucher(inst, ante) == Telescope) {
      telescopeAnte = ante;
      activate_voucher(inst, Telescope);
    }
    if (telescopeAnte != 99 && observatoryAnte == 99 &&
        next_voucher(inst, ante) == Observatory) {
      observatoryAnte = ante;
      activate_voucher(inst, Observatory);
    }

    // --- Tag Processing (adapted from negskips) ---
    item firstTag = next_tag(inst, ante);
    item secondTag = next_tag(inst, ante);
    int current_double_tags =
        double_tags; // Store tags before processing this ante's tags

    // Process First Tag (Big Blind Skip)
    if (firstTag == Double_Tag) {
      double_tags++;
    } else if (firstTag == Negative_Tag) {
      int tag_hits = 0;
      // Use the first Negative Tag immediately
      tag_hits += evaluateNegativeTagJokerForEpic(inst, ante, Needs, NUM_NEEDS,
                                                  Wants, NUM_WANTS, &negJokers);
      // Consume accumulated Double Tags
      for (int w = 0; w < current_double_tags; w++) {
        tag_hits += evaluateNegativeTagJokerForEpic(
            inst, ante, Needs, NUM_NEEDS, Wants, NUM_WANTS, &negJokers);
      }
      // Only reset double_tags and increment negTags score if the tag(s) hit
      // something useful
      if (tag_hits > 0) {
        negTags += tag_hits; // Increment score counter by number of hits
        double_tags = 0;     // Double tags were used
      } else {
        double_tags = current_double_tags; // Tag didn't find anything useful,
                                           // keep the double tags
      }
    }

    // Process Second Tag (Small Blind Skip)
    current_double_tags =
        double_tags; // Update count *after* processing first tag
    if (secondTag == Double_Tag) {
      double_tags++;
    } else if (secondTag == Negative_Tag) {
      int tag_hits = 0;
      // Use the second Negative Tag immediately
      tag_hits += evaluateNegativeTagJokerForEpic(inst, ante, Needs, NUM_NEEDS,
                                                  Wants, NUM_WANTS, &negJokers);
      // Consume accumulated Double Tags
      for (int w = 0; w < current_double_tags; w++) {
        tag_hits += evaluateNegativeTagJokerForEpic(
            inst, ante, Needs, NUM_NEEDS, Wants, NUM_WANTS, &negJokers);
      }
      if (tag_hits > 0) {
        negTags += tag_hits;
        double_tags = 0;
      } else {
        double_tags = current_double_tags;
      }
    }

    // --- Shop and Pack Checks (from template-pi) ---
    shopitem shItems[6] = {};
    item cards[36] = {RETRY}; // Simplified init
    for (int i = 0; i < 36; ++i)
      cards[i] = RETRY; // Ensure all are RETRY

    int cardsIndex = 0;
    shItems[0] = next_shop_item(inst, ante);
    shItems[1] = next_shop_item(inst, ante);
    shItems[2] = next_shop_item(inst, ante);
    shItems[3] = next_shop_item(inst, ante);
    if (ante > 1) { // Shop size increases after ante 1
      shItems[4] = next_shop_item(inst, ante);
      shItems[5] = next_shop_item(inst, ante);
    } else {
      shItems[4].value = RETRY; // Ensure empty slots are RETRY
      shItems[5].value = RETRY;
    }

    for (int sh = 0; sh < 6; sh++) {
      if (shItems[sh].value == RETRY)
        continue;
      if (shItems[sh].type == ItemType_Joker) {
#ifdef _debugPrints
        printf("Shop item %d: ", sh);
        print_item(shItems[sh]);
#endif
        if (shItems[sh].joker.edition == Negative)
          negJokers++; // Count negative jokers found in shop
        cards[cardsIndex++] =
            shItems[sh].value; // Add joker value to cards array
      } else {
        cards[cardsIndex++] =
            shItems[sh].value; // Add other item types too (like vouchers if
                               // needed later)
      }
    }

    // Pack checks
    int packChecks = ante == 1 ? 4 : 6; // Standard/Buffoon packs
#ifdef _debugPrints
    printf("performing %d pack checks for ante %d\n", packChecks, ante);
#endif

    for (int p = 0; p < packChecks && cardsIndex < 35;
         p++) { // Prevent overflow
      item cardsTemp[5] = {RETRY, RETRY, RETRY, RETRY, RETRY};
      pack _pack = pack_info(next_pack(inst, ante));
      if (_pack.type == Arcana_Pack)
        arcana_pack(cardsTemp, _pack.size, inst, ante);
      else if (_pack.type == Spectral_Pack)
        spectral_pack(cardsTemp, _pack.size, inst, ante);
      else if (_pack.type == Buffoon_Pack)
        buffoon_pack(cardsTemp, _pack.size, inst, ante);
      else
        continue; // Skip other pack types

#ifdef _debugPrints
      printf("Opening Pack %d (%d):\n", p, _pack.type);
#endif
      for (int t = 0; t < _pack.size && cardsIndex < 35;
           t++) { // Use actual pack size, prevent overflow
        if (cardsTemp[t] == RETRY)
          continue;
#ifdef _debugPrints
        print_item(cardsTemp[t]);
        printf(" ");
#endif
        cards[cardsIndex++] = cardsTemp[t];
      }
#ifdef _debugPrints
      printf("\ncardsIndex: %d\n", cardsIndex);
#endif
    }

// --- Check collected cards for Needs/Wants (from template-pi) ---
#ifdef _debugPrints
    printf("\n\n  --  Time to check the collected cards.  --\n");
#endif
    bool magic =
        false; // For Lucky Cat interaction if needed, keep from template
    for (int c = 0; c < cardsIndex; c++) {
      item current_card = cards[c];
      if (current_card == RETRY)
        continue;

      // *** FIX: Skip Vouchers in this loop, they are scored by next_voucher ***
      if (current_card == Observatory || current_card == Telescope) {
          continue;
      }

      // Handle special cards first
      if (current_card == Showman) {
        inst->params.showman = true; // Set flag
      }
      if (current_card == The_Magician) {
        magic = true;
      }
      if (current_card == The_Soul) {
        current_card =
            next_joker(inst, S_Soul, ante); // Replace Soul with its joker
        if (current_card == RETRY)
          continue; // Skip if Soul gives nothing
        switch (current_card) {
        case Perkeo:
          perkeoAnte = perkeoAnte == 99 ? ante : perkeoAnte;
          break;
        case Canio:
          canioAnte = canioAnte == 99 ? ante : canioAnte;
          break;
        case Triboulet:
          tribouletAnte = tribouletAnte == 99 ? ante : tribouletAnte;
          break;
        case Yorick:
          yorickAnte = yorickAnte == 99 ? ante : yorickAnte;
          break;
        case Chicot:
          chicotAnte = chicotAnte == 99 ? ante : chicotAnte;
          break;
        default:
          break; // Handle other jokers as needed
        }
      }

      // Add other spectral card -> joker conversions if needed

      // Check against Needs
      for (int x = 0; x < NUM_NEEDS; x++) {
        if (current_card == Needs[x] &&
            (ScoreNeeds[x] == false || inst->params.showman == true)) {
          ScoreNeeds[x] = true;
          if (current_card == Perkeo) {
            perkeo = true;     // Track Perkeo specifically
            perkeoAnte = ante; // Store ante when Perkeo was found
          }
#ifdef _debugPrints
          printf("Found Need: ");
          print_item(current_card);
          printf("\n");
#endif
          break; // Found in Needs, no need to check Wants
        }
      }

      // Check against Wants (only if not a Need or if Showman allows
      // duplicates)
      bool isNeed = false;
      for (int n = 0; n < NUM_NEEDS; ++n)
        if (current_card == Needs[n])
          isNeed = true;

      if (!isNeed || inst->params.showman) {
        for (int x = 0; x < NUM_WANTS; x++) {
          // Allow multiple Wants if Showman is active
          if (current_card == Wants[x] &&
              (ScoreWants[x] == 0 || inst->params.showman == true)) {
            ScoreWants[x]++;
#ifdef _debugPrints
            printf("Found Want: ");
            print_item(current_card);
            printf(" (Count: %d)\n", ScoreWants[x]);
#endif
            break;
          }
        }
      }
    } // End card checking loop

    // --- Ante-based Checks (from template-pi) ---
    if (ante == NEED_BY_ANTE) {
      for (int n = 0; n < NUM_NEEDS; n++) {
        // Special check for Perkeo based on its own deadline
        if (Needs[n] == Perkeo && ante < NEED_BY_ANTE_PERKEO)
          continue;

        if (ScoreNeeds[n] == false) {
#ifdef _debugPrints
          printf("Returning Score=0 because Need not found by ante %d: ", ante);
          print_item(Needs[n]);
          printf("\n");
#endif
          return 0; // Missing a required Need by the deadline
        }
      }
    }
    // Specific check for Perkeo at its deadline
    if (ante == NEED_BY_ANTE_PERKEO) {
      if (perkeo == false) {
#ifdef _debugPrints
        printf("Returning Score=0 because Perkeo not found by ante %d\n", ante);
#endif
        return 0;
      }
    }
    // Check if Perkeo is found before its wait time (optional early exit)
    if (perkeo && ante < WAIT_FOR_ANTE_PERKEO) {
#ifdef _debugPrints
      printf(
          "Returning Score=0 because Perkeo found too early (before ante %d)\n",
          WAIT_FOR_ANTE_PERKEO);
#endif
      // return 0; // Uncomment if finding Perkeo too early is bad
    }

    // Anaglyph Deck Bonus: Gain 1 Double Tag after defeating the Boss Blind
    // (end of ante)
    
    double_tags++;
#ifdef _debugPrints
    printf(
        "End of Ante %d. Double Tags: %d, Neg Tags Score: %d, Neg Jokers: %d\n",
        ante, double_tags, negTags, negJokers);
#endif

  } // End ante loop

  // --- Final Score Calculation (from template-pi) ---
  // Check if Observatory was found (it's a Want, but maybe make it required?)
  // bool foundObservatory = false;
  // for(int w=0; w<NUM_WANTS; ++w) if(Wants[w] == Observatory && ScoreWants[w]
  // > 0) foundObservatory = true; if (!foundObservatory) return 0; // Uncomment
  // if Observatory is absolutely required

  // Check if all Needs met by the end
  for (int n = 0; n < NUM_NEEDS; n++) {
    if (ScoreNeeds[n] == false) {
#ifdef _debugPrints
      printf("Returning Score=0 because Need not found by end: ");
      print_item(Needs[n]);
      printf("\n");
#endif
      return 0;
    }
  }

  if (telescopeAnte == 99 || observatoryAnte == 99) {
#ifdef _debugPrints
    printf("Returning Score=0 because Observatory not found\n");
#endif
    return 0; // Observatory not found
  }

  if (perkeoAnte == 99) {
#ifdef _debugPrints
    printf("Returning Score=0 because Perkeo not found\n");
#endif

    return 0; // Perkeo not found
  }


  long score = 0;
  long satisfiedWants = 0;
  for (int w = 0; w < NUM_WANTS; w++) {
    satisfiedWants +=
        ScoreWants[w] > 2
            ? 3
            : ScoreWants[w]; // Cap at 3 for distinct Wants satisfied
    // Use ScoreWants[w] directly, allowing multiple counts if showman=true
    score += (ScoreWants[w] > 9 ? 9 : ScoreWants[w]) *
             ScoreDigits[w]; // Middle digits based on count of each Want
  }
  score += (satisfiedWants > 9 ? 9 : satisfiedWants) *
           _DFirst; // First digit based on *number* of distinct Wants satisfied
  score += (negTags > 9 ? 9 : negTags) *
           _D7; // Use negTags counter (capped at 9 for the digit)
  score += (negJokers > 9 ? 9 : negJokers) *
           _DLast; // Use negJokers counter (capped at 9 for the digit)

#ifdef _debugPrints
  printf("Final Score: %ld\n", score);
#endif

  if (score > 100000000) {
    if (perkeoAnte != 99)
        printf("\nperkeo ante: %i, ", perkeoAnte);
    if (tribouletAnte != 99)
        printf("triboulet ante: %i, ", tribouletAnte);
    if (canioAnte != 99)
        printf(" canio ante: %i, ", canioAnte);
    if (yorickAnte != 99)
        printf(" yorick ante: %i, ", yorickAnte);
    if (chicotAnte != 99)
        printf(" chiocot ante: %i, ", chicotAnte);

    if (observatoryAnte != 99)
        printf(" observatory ante: %i, ", observatoryAnte);
    if (telescopeAnte != 99)
        printf(" telescope ante: %i, ", telescopeAnte);
  }

  return score;
}
