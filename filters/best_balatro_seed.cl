// Specialized filter for the BEST Balatro seed based on user preferences
filter Best_Balatro_Seed {
    // Absolute requirements: Perkeo, Telescope, Observatory, and Lucky_Cat before Ante 8
    if (!has_item_before_ante(Perkeo, 8) || !has_item_before_ante(Telescope, 8) || !has_item_before_ante(Observatory, 8) || !has_item_before_ante(Lucky_Cat, 8)) {
        return 0; // Fail if any requirement is not met
    }

    // Ensure Ghost_Deck hand size is 5 unless Blank and Antimatter are present
    if (deck == Ghost_Deck && hand_size != 5) {
        if (!(has_item(Blank) && has_item(Antimatter))) {
            return 0; // Fail if hand size is not 5 and Blank/Antimatter are missing
        }
    }

    // Calculate score based on the number of jokers
    int joker_count = 0;
    for (jokerdata joker : jokers) {
        if (joker.edition == Negative) {
            continue; // Negative edition jokers do not take up a slot
        }
        joker_count++;
    }

    // Include Blueprint and Brainstorm for re-triggering jokers
    if (has_item(Blueprint) || has_item(Brainstorm)) {
        joker_count += 2; // Bonus for having these items
    }

    // Add DNA for card duplication
    if (has_item(DNA)) {
        joker_count += 1; // Bonus for DNA
    }

    // Add Space_Joker and prioritize Oops_All_6s for hand level-ups
    if (has_item(Space_Joker)) {
        joker_count += 1; // Bonus for Space_Joker
        if (has_item(Oops_All_6s)) {
            joker_count += 2; // Extra bonus for Oops_All_6s synergy
        }
    }

    return joker_count; // Return the score based on the number of jokers
}