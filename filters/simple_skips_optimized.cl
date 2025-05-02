#include "lib/immolate.cl"
#define CACHE_SIZE 100
#define FIXED_FILTER_CUTOFF
#define OTHER_SCORE 1000
#define RETRIG_SCORE 1001
#define OOPS_SCORE 1011
#define BP_SCORE 1111

long checkNextCard(instance *inst, int ante) {
  shopitem _item = next_shop_item(inst, ante);
  int fb = 0;
  if (_item.type != ItemType_Joker || _item.joker.edition != No_Edition) {
    _item = next_shop_item(inst, ante);
  }

  if (_item.type != ItemType_Joker || _item.joker.edition != No_Edition) {
    return 0;
  }

  // Use a lookup table to reduce branch divergence
  const int score_lookup[] = {
      [Troubadour] = OTHER_SCORE, [Juggler] = OTHER_SCORE,
      [Sock_and_Buskin] = RETRIG_SCORE, [Hanging_Chad] = RETRIG_SCORE, [Baron] = RETRIG_SCORE, [Mime] = RETRIG_SCORE,
      [Oops_All_6s] = OOPS_SCORE, 
      [Brainstorm] = BP_SCORE, [Blueprint] = BP_SCORE};

  return score_lookup[_item.value];
}

int findNextCard(instance *inst, int ante, int *rra) {
  next_shop_item(inst, ante);
  next_shop_item(inst, ante); // two throw away calls
  for (; *rra < (90+ante); (*rra)++) {
    int score = checkNextCard(inst, ante);
    if (score > OTHER_SCORE) return score;
    int score2 = checkNextCard(inst, ante);
    if (score + score2 > OTHER_SCORE) return score2;
  }
  return 0;
}

long checkAnteForShowman(instance *inst, int ante) {
  // Inline the repeated calls to next_shop_item
  for (int i = 0; i < 4; i++) {
    if (next_shop_item(inst, ante).value == Showman) {
      inst->params.showman = true;
      return 1;
    }
  }
  return 0;
}

long filter(instance *inst) {
  set_deck(inst, Anaglyph_Deck);

  long score = 0;
  int dt = 0;
  int nt = 0;
  int perkeoAnte = 99;
  int observatoryAnte = 99;
  int antimatterAnte = 99;
  bool showman = false;
  int hitsA = 0;
  int hitsB = 0;
  int hitsC = 0;
  long bestScore = 0;
  int bestAnte = 0;
  int rerollsOnAnte = 0;

  item firstTag = RETRY;
  item secondTag = RETRY;
  int bp = 0;

  init_locks(inst, 1, false, true);

  for (int a = 1; a <= 10; a++) {
    if ((a == 4 && bp < 1) || (a == 6 && !inst->params.showman) || (a > 4 && perkeoAnte == 99) || (a > 6 && observatoryAnte == 99) || (a == 8 && antimatterAnte == 99)) {
      return 0;
    }

    init_unlocks(inst, a, false);
    firstTag = next_tag(inst, a);

    item voucher = next_voucher(inst, a);
    switch (voucher) {
      case Telescope:
        activate_voucher(inst, Telescope);
        break;
      case Observatory:
        observatoryAnte = a;
        activate_voucher(inst, Observatory);
        break;
      case Blank:
        activate_voucher(inst, Blank);
        break;
      case Antimatter:
        antimatterAnte = a;
        activate_voucher(inst, Antimatter);
        break;
      default:
        if (a > 1 && voucher != Hieroglyph) activate_voucher(inst, voucher);
        break;
    }

    if (firstTag == Double_Tag) dt++;

    if (!inst->params.showman && checkAnteForShowman(inst, a) > 0) {
      inst->params.showman = true;
    }
    if (firstTag == Negative_Tag) {

      int rra = 0;
      long trigScore = (firstTag == Negative_Tag) ? findNextCard(inst, a, &rra) : 0;
      for (int t = 0; t < dt; t++) {
        trigScore += checkNextCard(inst, a);
      }

      // Search for 3 chunks see what's best ... 
      long trigScore2 = 0;
      for (int i = 0; i < 3; i++) {
        int dead = 0;
        trigScore2 = findNextCard(inst, a, &rra);
        for (int t = 0; t < dt; t++) {
          long tempScore = checkNextCard(inst, a);
          trigScore2 += tempScore;
          if (tempScore == 0) {
            dead++;
          } else {
            dead = 0;
          }
        }
        for (int i = 0; i < dead; i+=2) {
          trigScore2 += checkNextCard(inst, a+1+i);
          trigScore2 += checkNextCard(inst, a+1+i);
        }
        if (trigScore2 > trigScore) {
          trigScore = trigScore2;
        }
      }

      trigScore = trigScore2 > trigScore ? trigScore2 : trigScore;
      bestScore = trigScore > 1 ? trigScore : 0;
      bestAnte = trigScore > bestScore ? a : bestAnte;
      rerollsOnAnte = trigScore > bestScore ? : rra;
    } else {
      bp += checkNextCard(inst, a) == BP_SCORE ? 1 : 0;
      bp += checkNextCard(inst, a) == BP_SCORE ? 1 : 0;
      bp += checkNextCard(inst, a) == BP_SCORE ? 1 : 0;
      bp += checkNextCard(inst, a) == BP_SCORE ? 1 : 0;
    }

    bool checkArcana = false;
    bool checkSpectral = false;
    int size = 3;
    if (firstTag == Charm_Tag || secondTag == Charm_Tag) {
      size = 5;
      checkArcana = true;
    }
    if (Ethereal_Tag == firstTag || Ethereal_Tag == secondTag) {
      size = 5;
      checkSpectral = true;
    }

    pack _pack = pack_info(next_pack(inst, a));
    if (_pack.type == Arcana_Pack) {
      checkArcana = true;
    } else if (_pack.type == Spectral_Pack) {
      checkSpectral = true;
    } else if (_pack.type == Buffoon_Pack) {
      item jkrs[5] = {RETRY, RETRY, RETRY, RETRY, RETRY};
      buffoon_pack(jkrs, _pack.size, inst, a);
      for (int i = 0; i < _pack.size; i++) {
        bp += jkrs[i] == Blueprint || jkrs[i] == Brainstorm ? 1 : 0;
        inst->params.showman = jkrs[i] == Showman ? true : inst->params.showman;
      }
    }

    item cards[5] = {RETRY, RETRY, RETRY, RETRY, RETRY};
    if (checkArcana) {
      arcana_pack(cards, size, inst, a);
    }
    if (checkSpectral) {
      spectral_pack(cards, size, inst, a);
    }

    for (int i = 0; i < 5; i++) {
      if (cards[i] == The_Soul) {
        jokerdata jkr = next_joker_with_info(inst, S_Soul, a);
        if (jkr.joker == Perkeo) {
          perkeoAnte = perkeoAnte == 99 ? a : perkeoAnte;
        }
      }
    }

    secondTag = next_tag(inst, a);
    if (secondTag == Double_Tag) dt++;
    dt++;
  }

 // recommended -c 110000 example real score: 221800
  return (bestScore) * 100000 + bp * 10000 + bestAnte * 100 + rerollsOnAnte;
}