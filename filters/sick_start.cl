#include "lib/immolate.cl"

long filter(instance* inst) {
    // Set up basic game parameters
    set_deck(inst, Ghost_Deck);
    set_stake(inst, White_Stake);
    init_locks(inst, 1, false, false);
    
    // Check for negative Oops_All_6s in first shop item
    shopitem firstItem = next_shop_item(inst, 1);
    bool hasNegativeOops = (firstItem.type == ItemType_Joker && 
                           firstItem.joker.joker == Oops_All_6s && 
                           firstItem.joker.edition == Negative);
    
    if (!hasNegativeOops) {
        return 0;
    }
    
    // Check for Ankh in the first 6 shop items
    bool hasAnkh = false;
    for (int i = 0; i < 5; i++) { // Check 5 more items (we already checked the first one)
        shopitem item = next_shop_item(inst, 1);
        if (item.type == ItemType_Spectral && item.value == Ankh) {
            hasAnkh = true;
            break;
        }
    }
    
    // Return 1 if we found both negative Oops_All_6s AND Ankh
    return (hasAnkh) ? 1 : 0;
}