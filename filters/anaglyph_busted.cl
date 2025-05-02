#include "lib/immolate.cl"

typedef struct {
    int slots;
    int bp;
    int bs;
    bool fibs;
    bool eight;
    int oops;
    bool negShowman;
    int jokerCount;
    int WjokerCount;
} JokerScoreContext;

long scoreJoker(instance *inst, jokerdata joker, JokerScoreContext *context) {
    if (context->slots <= 0 && joker.edition != Negative) {
        return 0;
    }
    long score = 0;
    switch (joker.joker) {
    case Showman:
        if (!inst->params.showman) {
            inst->params.showman = true;
            context->slots--;
            context->jokerCount++;
        }
        if (joker.edition == Negative && !context->negShowman) {
            context->negShowman = true;
            context->slots++;
        }
        break;
    case Oops_All_6s:
        if (context->oops == 0 || inst->params.showman) {
            context->oops++;
            score += 100000;
        }
        break;
    case Blueprint:
        if (context->bp == 0 || inst->params.showman) {
            context->bp++;
            score += 10000;
        }
        break;
    case Brainstorm:
        if (context->bs == 0 || inst->params.showman) {
            context->bs++;
            score += 10000;
        }
        break;
    case Invisible_Joker:
        score += 1000;
        break;
    case Fibonacci:
        if (!context->fibs) {
            context->fibs = true;
            score += 100;
        }
        break;
    case _8_Ball:
        if (!context->eight) {
            context->eight = true;
            score += 10;
        }
        break;
    default:
        score += (joker.edition == Negative) ? 1 : 0;
        break;
    }
    if (joker.edition != Negative && score > 0 && context->slots > 0) {
        context->slots--;
        context->jokerCount++;
        context->WjokerCount++;
    } else if (joker.edition == Negative) {
        context->jokerCount++;
        context->WjokerCount += (score > 1) ? 1 : 0;
    }
    return score;
}

long filter(instance *inst) {
    set_deck(inst, Anaglyph_Deck);
    long totalScore = 0;
    JokerScoreContext context = {5, 0, 0, false, false, 0, false, 0, 0};
    bool perkeo = false;

    for (int a = 1; a <= 10; a++) {
        init_unlocks(inst, a, false);
        item voucher = next_voucher(inst, a);
        if (a > 1) activate_voucher(inst, voucher);
        if (voucher == Antimatter) {
            context.slots++;
        }
        if (context.WjokerCount > 1 && !inst->params.showman) {
            return 0;
        }
        if (a > 6 && !perkeo) {
            return 0;
        }
        if (a > 3 && !inst->params.showman) {
            return 0;
        }
        if (a > 4 && (!context.eight || !(context.bp || context.bs))) {
            return 0;
        }
        if (a > 5 && (!context.fibs || context.oops < 1)) {
            return 0;
        }
        int rows = a == 1 ? 4 : 6;
        for (int an = 0; an < rows; an++) {
            shopitem _item = next_shop_item(inst, a);
            if (_item.type == ItemType_Joker) {
                totalScore += scoreJoker(inst, _item.joker, &context);
            }
            pack _pack = pack_info(next_pack(inst, a));
            if (_pack.type != Buffoon_Pack) {
                item cards[5] = {RETRY, RETRY, RETRY, RETRY, RETRY};
                if (_pack.type == Spectral_Pack) {
                    spectral_pack(cards, _pack.size, inst, a);
                } else if (_pack.type == Arcana_Pack) {
                    arcana_pack(cards, _pack.size, inst, a);
                }
                for (int i = 0; i < _pack.size; i++) {
                    if (cards[i] == The_Soul) {
                        jokerdata sJkr = next_joker_with_info(inst, S_Soul, a);
                        if (sJkr.joker == Perkeo) {
                            perkeo = true;
                        }
                        if (sJkr.edition == Negative) {
                            context.slots++;
                        }
                    }
                }
            } else {
                jokerdata cards[5];
                buffoon_pack_detailed(cards, _pack.size, inst, a);
                for (int i = 0; i < _pack.size; i++) {
                    totalScore += scoreJoker(inst, cards[i], &context);
                }
            }
        }
    }
    return (context.jokerCount) * 10000000 + (context.WjokerCount) * 1000000 + totalScore;
}