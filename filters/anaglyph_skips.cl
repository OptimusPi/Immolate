// filepath: x:\Immolate\filters\anaglyph_skips.cl
#include "lib/immolate.cl"
#define CACHE_SIZE 128

// Define score magnitudes (similar to template-pi.cl)
// Max score should be < 2,147,483,647 (signed 4-byte int limit)
#define SCORE_PERKEO_OBSERVATORY 500000000 // 500M
#define SCORE_NEG_BLUEPRINT_BRAIN 100000000 // 100M
#define SCORE_NEG_SHOWMAN          50000000 //  50M
#define SCORE_TAGGED_PERKEO        20000000 //  20M
#define SCORE_TAGGED_BLUE_BRAIN    10000000 //  10M
#define SCORE_TAGGED_SHOWMAN        5000000 //   5M
#define SCORE_EARLY_PERKEO          2000000 //   2M
#define SCORE_PLAIN_PERKEO          1000000 //   1M
#define SCORE_PLAIN_BLUE_BRAIN       500000 // 500k
#define SCORE_PLAIN_SHOWMAN          200000 // 200k
#define SCORE_OTHER_NEGATIVE         100000 // 100k
#define SCORE_OBSERVATORY_NO_PERKEO   50000 //  50k
#define SCORE_TELESCOPE                1000 //   1k
#define SCORE_TAGGED_OTHER             100 //  100

// Function to evaluate Jokers found after a Negative Tag triggers
long evaluateNegativeTagJoker(instance* inst, int ante) {
    long score = 0;
    shopitem _item = next_shop_item(inst, ante);

    // Check the next few slots for an immediate Negative Joker (high value)
    for (int i = 0; i < 5; i++) { // Look ahead 5 slots
        if (_item.type == ItemType_Joker && _item.joker.edition == Negative) {
            // Found an inherent Negative Joker - check if it's one we want
            if (_item.value == Blueprint || _item.value == Brainstorm) return SCORE_NEG_BLUEPRINT_BRAIN;
            if (_item.value == Showman) return SCORE_NEG_SHOWMAN;
            if (_item.value == Perkeo) return SCORE_TAGGED_PERKEO; // Treat inherent Neg Perkeo same as tagged for simplicity here
            return SCORE_OTHER_NEGATIVE; // Any other Negative is still good
        }
        if (_item.type == ItemType_Joker && _item.joker.edition == No_Edition) break; // Found the plain joker the tag will affect
        _item = next_shop_item(inst, ante); // Check next item
    }

    // If we didn't find an inherent Negative, evaluate the plain Joker the tag hits
    if (_item.type != ItemType_Joker || _item.joker.edition != No_Edition) return 0; // Tag hits nothing useful

    // Score based on the Joker type being made Negative by the tag
    if (_item.value == Blueprint || _item.value == Brainstorm) return SCORE_TAGGED_BLUE_BRAIN;
    if (_item.value == Showman) return SCORE_TAGGED_SHOWMAN;
    if (_item.value == Perkeo) return SCORE_TAGGED_PERKEO;
    // Add other jokers if needed, give them a smaller score
    if (_item.value == Mime || _item.value == Baron) return SCORE_TAGGED_OTHER;

    return 0; // Joker wasn't on our list
}


long filter(instance *inst) {
    long score = 0;
    int double_tags = 0; // Track accumulated Double Tags

    // Flags to track if we've found key items
    bool foundPerkeo = false;
    bool foundShowman = false;
    bool foundTelescope = false;
    bool foundObservatory = false;
    bool foundBlueprint = false;
    bool foundBrainstorm = false;

    set_deck(inst, Anaglyph_Deck);
    set_stake(inst, White_Stake);
    init_locks(inst, 1, false, false); // Lock seed settings
    inst->params.showman = false; // Ensure showman starts false

    for (int a = 1; a <= 8; a++) { // Loop through antes 1 to 8
        init_unlocks(inst, a, false); // Unlock RNG for this ante

        // --- Ante 1 Specific Checks ---
        if (a == 1) {
            // Check for early Showman (important for duplicates)
            shopitem shop1 = next_shop_item(inst, a);
            shopitem shop2 = next_shop_item(inst, a);
            if (shop1.type == ItemType_Joker && shop1.value == Showman) {
                if (!foundShowman) score += SCORE_PLAIN_SHOWMAN;
                foundShowman = true;
                inst->params.showman = true; // Set the flag
            }
            if (shop2.type == ItemType_Joker && shop2.value == Showman) {
                 if (!foundShowman) score += SCORE_PLAIN_SHOWMAN;
                foundShowman = true;
                inst->params.showman = true; // Set the flag
            }

            // Check for The Soul card in the first Arcana pack (requires Charm Tag)
            item firstTagAnte1 = next_tag(inst, a);
            item secondTagAnte1 = next_tag(inst, a);
            bool hasCharmTag = (firstTagAnte1 == Charm_Tag || secondTagAnte1 == Charm_Tag);

            if (hasCharmTag) {
                item arcanaPack[5];
                arcana_pack(arcanaPack, 5, inst, true); // Open the guaranteed pack
                bool hasSoul = false;
                for (int i = 0; i < 5; i++) {
                    if (arcanaPack[i] == The_Soul) {
                        hasSoul = true;
                        break;
                    }
                }

                if (hasSoul) {
                    // Check if The Soul gives Perkeo
                    item soulJoker = next_joker(inst, S_Soul, 1); // Get joker from Soul card
                    if (soulJoker == Perkeo) {
                        if (!foundPerkeo) score += SCORE_EARLY_PERKEO; // Significant score for finding Perkeo early
                        foundPerkeo = true;
                    }
                }
            }
        }

        // --- General Ante Logic ---

        // Check Vouchers first (separate from shop items)
        if (!foundTelescope && next_voucher(inst, a) == Telescope) {
            foundTelescope = true;
            score += SCORE_TELESCOPE;
            activate_voucher(inst, Telescope); // Activate for subsequent checks
        }
        // Check for Observatory only if Telescope was found previously
        if (foundTelescope && !foundObservatory && next_voucher(inst, a) == Observatory) {
            foundObservatory = true;
            // Add the massive combo score, potentially replacing lower observatory score if perkeo wasn't found yet
            score += foundPerkeo ? SCORE_PERKEO_OBSERVATORY : SCORE_OBSERVATORY_NO_PERKEO;
            // No need to activate Observatory for this filter's logic
        }

        // Check Shops for key Jokers
        for (int shop_idx = 0; shop_idx < 4; ++shop_idx) { // Check first 4 shop slots
             shopitem current_item = next_shop_item(inst, a);
             if (current_item.type == ItemType_Joker) {
                 long item_score = 0;
                 bool is_neg = (current_item.joker.edition == Negative);

                 if (current_item.value == Blueprint) {
                     if (!foundBlueprint || inst->params.showman) item_score = is_neg ? SCORE_NEG_BLUEPRINT_BRAIN : SCORE_PLAIN_BLUE_BRAIN;
                     foundBlueprint = true;
                 } else if (current_item.value == Brainstorm) {
                     if (!foundBrainstorm || inst->params.showman) item_score = is_neg ? SCORE_NEG_BLUEPRINT_BRAIN : SCORE_PLAIN_BLUE_BRAIN;
                     foundBrainstorm = true;
                 } else if (current_item.value == Showman) {
                     if (!foundShowman) item_score = is_neg ? SCORE_NEG_SHOWMAN : SCORE_PLAIN_SHOWMAN;
                     foundShowman = true;
                     inst->params.showman = true; // Set the flag
                 } else if (current_item.value == Perkeo) {
                     if (!foundPerkeo || inst->params.showman) item_score = is_neg ? SCORE_TAGGED_PERKEO : SCORE_PLAIN_PERKEO; // Use tagged score for neg plain perkeo
                     foundPerkeo = true;
                 } else if (is_neg) {
                     // Score any other negative joker found in shop
                     item_score = SCORE_OTHER_NEGATIVE;
                 }
                 score += item_score;
             }
        }

        // Get Tags for the current ante
        item firstTag = next_tag(inst, a);
        item secondTag = next_tag(inst, a);

        // --- Tag Processing ---
        int current_double_tags = double_tags; // Store tags before processing this ante's tags

        // Process First Tag (Big Blind Skip)
        if (firstTag == Double_Tag) {
            double_tags++;
        } else if (firstTag == Negative_Tag) {
            long tag_score = 0;
            // Use the first Negative Tag immediately
            tag_score += evaluateNegativeTagJoker(inst, a);
            // Consume accumulated Double Tags (from previous antes + Anaglyph)
            for (int w = 0; w < current_double_tags; w++) {
                tag_score += evaluateNegativeTagJoker(inst, a);
            }
            // Only reset double_tags if the tag actually yielded a score
            if (tag_score > 0) {
                score += tag_score;
                double_tags = 0; // Double tags were used by this tag
            } else {
                // Tag didn't find anything useful, keep the double tags
                double_tags = current_double_tags;
            }
        }
        // Add checks for other useful tags here if needed

        // Process Second Tag (Small Blind Skip)
        // Need to know if the first tag used the double tags
        current_double_tags = double_tags; // Update count *after* processing first tag
        if (secondTag == Double_Tag) {
            double_tags++;
        } else if (secondTag == Negative_Tag) {
            long tag_score = 0;
            // Use the second Negative Tag immediately
            tag_score += evaluateNegativeTagJoker(inst, a);
            // Consume accumulated Double Tags (potentially including one from the first tag slot)
            for (int w = 0; w < current_double_tags; w++) {
                tag_score += evaluateNegativeTagJoker(inst, a);
            }
            // Only reset double_tags if the tag actually yielded a score
            if (tag_score > 0) {
                score += tag_score;
                double_tags = 0; // Double tags were used by this tag
            } else {
                 // Tag didn't find anything useful, keep the double tags
                double_tags = current_double_tags;
            }
        }
        // Add checks for other useful tags here if needed

        // Anaglyph Deck Bonus: Gain 1 Double Tag after defeating the Boss Blind (end of ante)
        double_tags++;

        // --- End of Ante ---
        // Optional: Add score based on finding combinations by this ante?
        // e.g., if (a == 4 && foundPerkeo && foundObservatory) score += 20000;
    }

    // Final check: Maybe require the absolute core combo for any score?
    if (!foundPerkeo || !foundObservatory) {
         return 0;
     }

    // Return the final calculated score for the seed
    // Ensure score is non-negative, though it shouldn't be possible to go negative here.
    return score > 0 ? score : 0;
}

