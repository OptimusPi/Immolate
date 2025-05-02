#include "lib/immolate.cl"
#define CACHE_SIZE 100
#define FIXED_FILTER_CUTOFF
#define OTHER_SCORE       1000001
#define HAND_SIZE_SCORE   1000010
#define RETRIG_SCORE      1000100
#define KINGY_SCORE       1001000
#define BP_SCORE          1010000
#define OOPS_SCORE        1100000

long checkNextCard(instance *inst, int ante) {
  shopitem _item = next_shop_item(inst, ante);

  if (_item.type != ItemType_Joker || _item.joker.edition != No_Edition) {
    return -1;
  }

  // Use a switch statement to handle all cases and provide a default value
  switch (_item.value) {
    case Bull:
    case Ramen:
    case Showman:
    case Pareidolia:
    case Astronomer:
    case Cartomancer:
    case Satellite:
    case The_Duo:
    case The_Trio:
        return OTHER_SCORE;
    case Troubadour:
    case Juggler:
    case Turtle_Bean:
    case DNA:
    case Hologram:
    case Space_Joker:
    case Burnt_Joker:
      return HAND_SIZE_SCORE;
    case Sock_and_Buskin:
    case Hanging_Chad:
    case Hack:
    case Seltzer:
    case Dusk:
      return RETRIG_SCORE;
    case Baron:
    case Mime:
      return KINGY_SCORE;
    case Oops_All_6s:
      return OOPS_SCORE;
    case Brainstorm:
    case Blueprint:
    case Invisible_Joker:
      return BP_SCORE;
    default:
      return -1; // Default value for undefined entries
  }
}

long findNextCard(instance *inst, int ante, int *rra) {
  long bestScore1 = 0;
  long bestScore2 = 0;

  // for simplicity sake assume that negativeTags == ante
  for (int i = 0; i < ante; i++) {
    bestScore1 += checkNextCard(inst, ante);
  }
  // Search again -- to see if this run of jokers in the shop is better
  for (int i = 0; i < ante; i++) {
    bestScore2 += checkNextCard(inst, ante);
  }
  return 0;
}

long checkAnteForShowman(instance *inst, int ante) {
  for (int i = 0; i < 4; i++) {
    shopitem item = next_shop_item(inst, ante);
    if (item.value == Showman) {
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
  long totalScore = 0;

  item firstTag = RETRY;
  item secondTag = RETRY;
  int goodies = 0;

  init_locks(inst, 1, false, true);

  for (int a = 1; a <= 22; a++) {
    if (
      (a > 2 && goodies < 1) ||
      (a > 3 && perkeoAnte == 99) || 
      (a > 4 && observatoryAnte == 99)
    ) {
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
    if (firstTag == Negative_Tag && inst->params.showman) {
      // next ante instead of searching
      long trigScore = 0;
      int checks = a-1+dt;

      for (int t = 0; t < 6 && t < checks; t++) {
        int dummyRRA = 0;
        int te = checkNextCard(inst, a+1);
        if (te >= 0) {
          checks --;
          trigScore += te;
        }
      }
      
      if (trigScore > bestScore) {
        bestScore = trigScore;
        totalScore += bestScore;
        bestAnte = bestAnte == 0 ? a : bestAnte;
      }
    } else {
      goodies += checkNextCard(inst, a) == BP_SCORE ? 1 : 0;
      goodies += checkNextCard(inst, a) == BP_SCORE ? 1 : 0;
      goodies += checkNextCard(inst, a) == BP_SCORE ? 1 : 0;
      goodies += checkNextCard(inst, a) == BP_SCORE ? 1 : 0;
      goodies += checkNextCard(inst, a) == BP_SCORE ? 1 : 0;
      goodies += checkNextCard(inst, a) == BP_SCORE ? 1 : 0;
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
        goodies += jkrs[i] == Blueprint || jkrs[i] == Brainstorm || jkrs[i] == Oops_All_6s ? 1 : 0;
        inst->params.showman = jkrs[i] == Showman ? true : inst->params.showman;
      }
    }

    item cards[5] = {RETRY, RETRY, RETRY, RETRY, RETRY};
    if (checkArcana) {
      arcana_pack(cards, size, inst, a);
    }
    else if (checkSpectral) {
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
  if (bestAnte == 0) {
    return 0;
  }

 // recommended -c 11000000 example real score: xxx
  return (totalScore) * 100 + bestAnte;
}