#ifndef TEMPLATE_OUIJI_CL
#define TEMPLATE_OUIJI_CL

#include "lib/ouiji.cl"

// Renamed filter function, now accepts the config struct
long ouiji_filter(instance* inst, __global OuijiConfig* config) {
    long score = 0;
    int ante = 1;
    item shop_item;
    item tag;
    item pack_item;
    item spectral_item;
    item voucher;
    item boss;
    item edition;
    jokerdata joker_info;

    // Use config->needByAnte and config->numNeeds
    // Temporarily lock needs based on config
    if (config->needByAnte > 0) {
        for (int i = 0; i < config->numNeeds; i++) {
            inst->locked[config->Needs[i]] = true;
        }
    }
    // Also lock Perkeo if it's a need, using its specific ante
    if (config->needByAntePerkeo > 0) {
        for (int i = 0; i < config->numNeeds; i++) {
             if (config->Needs[i] == Perkeo) {
                 inst->locked[Perkeo] = true;
                 break; // Only need to lock it once
             }
        }
    }


    // --- Ante 1 ---
    // Shop 1
    shop_item = next_shop_item(inst, ante).value;
    for (int i = 0; i < config->numNeeds; i++) {
        if (shop_item == config->Needs[i]) {
            if (ante > (config->Needs[i] == Perkeo ? config->needByAntePerkeo : config->needByAnte)) return 0;
            inst->locked[shop_item] = false;
        }
    }
    for (int i = 0; i < config->numWants; i++) {
        if (shop_item == config->Wants[i]) {
            if (ante <= config->wantByAnte) score++;
        }
    }
    // Shop 2
    shop_item = next_shop_item(inst, ante).value;
     for (int i = 0; i < config->numNeeds; i++) {
        if (shop_item == config->Needs[i]) {
            if (ante > (config->Needs[i] == Perkeo ? config->needByAntePerkeo : config->needByAnte)) return 0;
            inst->locked[shop_item] = false;
        }
    }
    for (int i = 0; i < config->numWants; i++) {
        if (shop_item == config->Wants[i]) {
            if (ante <= config->wantByAnte) score++;
        }
    }
    // Tag
    tag = next_tag(inst, ante);
    if (tag == Boss_Tag) {
        boss = next_boss(inst, ante);
        // Check boss for needs/wants if necessary
    } else if (tag == Voucher_Tag) {
        voucher = next_voucher_from_tag(inst, ante);
         for (int i = 0; i < config->numNeeds; i++) {
            if (voucher == config->Needs[i]) {
                 if (ante > (config->Needs[i] == Perkeo ? config->needByAntePerkeo : config->needByAnte)) return 0;
                 inst->locked[voucher] = false;
            }
        }
        for (int i = 0; i < config->numWants; i++) {
            if (voucher == config->Wants[i]) {
                if (ante <= config->wantByAnte) score++;
            }
        }
        activate_voucher(inst, voucher);
    } else if (tag == Buffoon_Tag) {
        pack_item = next_pack(inst, ante);
        if (pack_item == Buffoon_Pack || pack_item == Jumbo_Buffoon_Pack || pack_item == Mega_Buffoon_Pack) {
            pack p_info = pack_info(pack_item);
            // Use fixed size array instead of VLA
            jokerdata buffoon_results[5];
            buffoon_pack_detailed(buffoon_results, p_info.size, inst, ante);
            // Loop still uses the actual pack size (p_info.size)
            for (int j=0; j<p_info.size; ++j) {
                for (int i = 0; i < config->numNeeds; i++) {
                    if (buffoon_results[j].joker == config->Needs[i]) {
                        if (ante > (config->Needs[i] == Perkeo ? config->needByAntePerkeo : config->needByAnte)) return 0;
                        inst->locked[buffoon_results[j].joker] = false;
                    }
                }
                for (int i = 0; i < config->numWants; i++) {
                    if (buffoon_results[j].joker == config->Wants[i]) {
                        if (ante <= config->wantByAnte) score++;
                    }
                }
            }
        }
    }
    // ... other tag checks ...

    // --- Ante 2 ---
    ante = 2;
    // Shop 1
    shop_item = next_shop_item(inst, ante).value;
     for (int i = 0; i < config->numNeeds; i++) {
        if (shop_item == config->Needs[i]) {
            if (ante > (config->Needs[i] == Perkeo ? config->needByAntePerkeo : config->needByAnte)) return 0;
            inst->locked[shop_item] = false;
        }
    }
    for (int i = 0; i < config->numWants; i++) {
        if (shop_item == config->Wants[i]) {
            if (ante <= config->wantByAnte) score++;
        }
    }
    // Shop 2
    shop_item = next_shop_item(inst, ante).value;
     for (int i = 0; i < config->numNeeds; i++) {
        if (shop_item == config->Needs[i]) {
            if (ante > (config->Needs[i] == Perkeo ? config->needByAntePerkeo : config->needByAnte)) return 0;
            inst->locked[shop_item] = false;
        }
    }
    for (int i = 0; i < config->numWants; i++) {
        if (shop_item == config->Wants[i]) {
            if (ante <= config->wantByAnte) score++;
        }
    }
    // Tag
    tag = next_tag(inst, ante);
     if (tag == Boss_Tag) {
        boss = next_boss(inst, ante);
    } else if (tag == Voucher_Tag) {
        voucher = next_voucher_from_tag(inst, ante);
         for (int i = 0; i < config->numNeeds; i++) {
            if (voucher == config->Needs[i]) {
                 if (ante > (config->Needs[i] == Perkeo ? config->needByAntePerkeo : config->needByAnte)) return 0;
                 inst->locked[voucher] = false;
            }
        }
        for (int i = 0; i < config->numWants; i++) {
            if (voucher == config->Wants[i]) {
                if (ante <= config->wantByAnte) score++;
            }
        }
        activate_voucher(inst, voucher);
    } else if (tag == Buffoon_Tag) {
        pack_item = next_pack(inst, ante);
        if (pack_item == Buffoon_Pack || pack_item == Jumbo_Buffoon_Pack || pack_item == Mega_Buffoon_Pack) {
            pack p_info = pack_info(pack_item);
            // Use fixed size array instead of VLA
            jokerdata buffoon_results[5];
            buffoon_pack_detailed(buffoon_results, p_info.size, inst, ante);
            // Loop still uses the actual pack size (p_info.size)
            for (int j=0; j<p_info.size; ++j) {
                for (int i = 0; i < config->numNeeds; i++) {
                    if (buffoon_results[j].joker == config->Needs[i]) {
                        if (ante > (config->Needs[i] == Perkeo ? config->needByAntePerkeo : config->needByAnte)) return 0;
                        inst->locked[buffoon_results[j].joker] = false;
                    }
                }
                for (int i = 0; i < config->numWants; i++) {
                    if (buffoon_results[j].joker == config->Wants[i]) {
                        if (ante <= config->wantByAnte) score++;
                    }
                }
            }
        }
    }
    // ... other tag checks ...

    // --- Ante 3 ---
    ante = 3;
    // Shop 1
    shop_item = next_shop_item(inst, ante).value;
     for (int i = 0; i < config->numNeeds; i++) {
        if (shop_item == config->Needs[i]) {
            if (ante > (config->Needs[i] == Perkeo ? config->needByAntePerkeo : config->needByAnte)) return 0;
            inst->locked[shop_item] = false;
        }
    }
    for (int i = 0; i < config->numWants; i++) {
        if (shop_item == config->Wants[i]) {
            if (ante <= config->wantByAnte) score++;
        }
    }
    // Shop 2
    shop_item = next_shop_item(inst, ante).value;
     for (int i = 0; i < config->numNeeds; i++) {
        if (shop_item == config->Needs[i]) {
            if (ante > (config->Needs[i] == Perkeo ? config->needByAntePerkeo : config->needByAnte)) return 0;
            inst->locked[shop_item] = false;
        }
    }
    for (int i = 0; i < config->numWants; i++) {
        if (shop_item == config->Wants[i]) {
            if (ante <= config->wantByAnte) score++;
        }
    }
    // Tag
    tag = next_tag(inst, ante);
     if (tag == Boss_Tag) {
        boss = next_boss(inst, ante);
    } else if (tag == Voucher_Tag) {
        voucher = next_voucher_from_tag(inst, ante);
         for (int i = 0; i < config->numNeeds; i++) {
            if (voucher == config->Needs[i]) {
                 if (ante > (config->Needs[i] == Perkeo ? config->needByAntePerkeo : config->needByAnte)) return 0;
                 inst->locked[voucher] = false;
            }
        }
        for (int i = 0; i < config->numWants; i++) {
            if (voucher == config->Wants[i]) {
                if (ante <= config->wantByAnte) score++;
            }
        }
        activate_voucher(inst, voucher);
    } else if (tag == Buffoon_Tag) {
        pack_item = next_pack(inst, ante);
        if (pack_item == Buffoon_Pack || pack_item == Jumbo_Buffoon_Pack || pack_item == Mega_Buffoon_Pack) {
            pack p_info = pack_info(pack_item);
            // Use fixed size array instead of VLA
            jokerdata buffoon_results[5];
            buffoon_pack_detailed(buffoon_results, p_info.size, inst, ante);
            // Loop still uses the actual pack size (p_info.size)
            for (int j=0; j<p_info.size; ++j) {
                for (int i = 0; i < config->numNeeds; i++) {
                    if (buffoon_results[j].joker == config->Needs[i]) {
                        if (ante > (config->Needs[i] == Perkeo ? config->needByAntePerkeo : config->needByAnte)) return 0;
                        inst->locked[buffoon_results[j].joker] = false;
                    }
                }
                for (int i = 0; i < config->numWants; i++) {
                    if (buffoon_results[j].joker == config->Wants[i]) {
                        if (ante <= config->wantByAnte) score++;
                    }
                }
            }
        }
    }
    // ... other tag checks ...

    // --- Ante 4 ---
    ante = 4;
    // Shop 1
    shop_item = next_shop_item(inst, ante).value;
     for (int i = 0; i < config->numNeeds; i++) {
        if (shop_item == config->Needs[i]) {
            if (ante > (config->Needs[i] == Perkeo ? config->needByAntePerkeo : config->needByAnte)) return 0;
            inst->locked[shop_item] = false;
        }
    }
    for (int i = 0; i < config->numWants; i++) {
        if (shop_item == config->Wants[i]) {
            if (ante <= config->wantByAnte) score++;
        }
    }
    // Shop 2
    shop_item = next_shop_item(inst, ante).value;
     for (int i = 0; i < config->numNeeds; i++) {
        if (shop_item == config->Needs[i]) {
            if (ante > (config->Needs[i] == Perkeo ? config->needByAntePerkeo : config->needByAnte)) return 0;
            inst->locked[shop_item] = false;
        }
    }
    for (int i = 0; i < config->numWants; i++) {
        if (shop_item == config->Wants[i]) {
            if (ante <= config->wantByAnte) score++;
        }
    }
    // Tag
    tag = next_tag(inst, ante);
     if (tag == Boss_Tag) {
        boss = next_boss(inst, ante);
    } else if (tag == Voucher_Tag) {
        voucher = next_voucher_from_tag(inst, ante);
         for (int i = 0; i < config->numNeeds; i++) {
            if (voucher == config->Needs[i]) {
                 if (ante > (config->Needs[i] == Perkeo ? config->needByAntePerkeo : config->needByAnte)) return 0;
                 inst->locked[voucher] = false;
            }
        }
        for (int i = 0; i < config->numWants; i++) {
            if (voucher == config->Wants[i]) {
                if (ante <= config->wantByAnte) score++;
            }
        }
        activate_voucher(inst, voucher);
    } else if (tag == Buffoon_Tag) {
        pack_item = next_pack(inst, ante);
        if (pack_item == Buffoon_Pack || pack_item == Jumbo_Buffoon_Pack || pack_item == Mega_Buffoon_Pack) {
            pack p_info = pack_info(pack_item);
            // Use fixed size array instead of VLA
            jokerdata buffoon_results[5];
            buffoon_pack_detailed(buffoon_results, p_info.size, inst, ante);
            // Loop still uses the actual pack size (p_info.size)
            for (int j=0; j<p_info.size; ++j) {
                for (int i = 0; i < config->numNeeds; i++) {
                    if (buffoon_results[j].joker == config->Needs[i]) {
                        if (ante > (config->Needs[i] == Perkeo ? config->needByAntePerkeo : config->needByAnte)) return 0;
                        inst->locked[buffoon_results[j].joker] = false;
                    }
                }
                for (int i = 0; i < config->numWants; i++) {
                    if (buffoon_results[j].joker == config->Wants[i]) {
                        if (ante <= config->wantByAnte) score++;
                    }
                }
            }
        }
    }
    // ... other tag checks ...

    // --- Final Check for Needs ---
    // Use config->numNeeds
    for (int i = 0; i < config->numNeeds; i++) {
        // Check if the need is still locked
        if (inst->locked[config->Needs[i]]) {
             // If it's Perkeo, check against its specific deadline
             if (config->Needs[i] == Perkeo) {
                 if (ante > config->needByAntePerkeo) return 0; // Failed Perkeo timing
             }
             // Otherwise, check against the general deadline
             else {
                 if (ante > config->needByAnte) return 0; // Failed general Need timing
             }
             // If we reach here and the need is still locked, it means it wasn't found by the deadline
             return 0;
        }
    }


    return score; // Return the calculated score based on Wants found
}

#endif // TEMPLATE_OUIJI_CL
