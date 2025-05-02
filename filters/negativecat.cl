#include "lib/immolate.cl"

long filter(instance* inst) {
    inst->params.showman = true;
    // Set up basic game parameters for negative jokers
    set_deck(inst, Ghost_Deck);
    set_stake(inst, Black_Stake); // Black stake for negative jokers
    init_locks(inst, 1, false, false);
    int score = 0;
    int magic = 0;
    int bp = 0;
    int oops = 0;
    int bs = 0;
    int neg = 0;
    int negTags = 0;
    int negWants = 0;
    bool cat = 0;
    bool hasShowman = false;
    int spaceman = 0;

    

    // Check first shop item for negative Lucky Cat
    if (next_shop_item(inst, 1).value != The_Magician && next_shop_item(inst, 1).value != The_Magician) {
        return 0;
    }
    
    shopitem item3 = next_shop_item(inst, 1);
    if (item3.type == ItemType_Joker && 
        item3.joker.joker == Lucky_Cat) {
        cat = true;
        if (item3.joker.edition == Negative) {
            negWants++;
        }
    }

    shopitem item4 = next_shop_item(inst, 1);
    if (item4.type == ItemType_Joker && 
        item4.joker.joker == Lucky_Cat) {
        cat = true;
        if (item3.joker.edition == Negative) {
            negWants++;
        }
    }
    if (cat == false) return 0;

    init_unlocks(inst, 2, false);
    if (next_tag(inst, 2) != Negative_Tag) {
        return 0;
    }

    for (int ante = 2; ante <= 8; ante++)
    {
        for (int i = 0; i < 4; i++) {
            if (next_tag(inst, ante) == Negative_Tag) {
                negTags++;
            }
            if (next_tag(inst, ante) == Negative_Tag) {
                negTags++;
            }
            next_orbital_tag(inst);

            shopitem _item = next_shop_item(inst, ante);
            if (_item.type == ItemType_Joker) {
                if (_item.joker.joker == Showman) {
                    hasShowman = true;
                    inst->params.showman = true;
                } else if (_item.joker.joker == Oops_All_6s && (hasShowman || oops == 0)) {
                    oops++;
                } else if (_item.joker.joker == Blueprint && (hasShowman || bp == 0)) {
                    bp++;
                } else if (_item.joker.joker == Brainstorm && (hasShowman || bs == 0)) {
                    bp++;
                } else if (_item.joker.joker == Space_Joker && (hasShowman || spaceman == 0)) {
                    spaceman++;
                } else if (_item.joker.edition == Negative) {
                    neg++;
                    continue;
                }
                if (_item.joker.edition == Negative) {
                    negWants++;
                    continue;
                }
            } else if (_item.value == Ectoplasm || _item.value == Temperance || _item.value == The_Magician || _item.value == The_Hermit) {
                magic++;
            } 
        }
        if (ante == 3 && (spaceman == 0 || oops == 0)) return 0;

        init_unlocks(inst, ante+1, false);
    }
    return oops*100000 + (bp+bs)*10000 + (negWants*1000) + (negTags*100) + (neg*10) + magic;
}