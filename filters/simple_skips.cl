#include "lib/immolate.cl"
#define CACHE_SIZE 200
//#define FIXED_FILTER_CUTOFF
#define BP_SCORE 100
long checkNextCard(instance *inst, int ante, int * rra) {
  shopitem _item = next_shop_item(inst, ante);
  int fb = 0;
  int rc = 0;
  while (_item.type != ItemType_Joker && _item.joker.edition != No_Edition) {
    _item = next_shop_item(inst, ante);
    *rra += rc % 2 == 0 ? 1 : 0;
  }
  switch (_item.value) {
    case Troubadour:
    case Juggler:
      return 1;
    case Sock_and_Buskin:
    case Hanging_Chad:
    case Baron:
    case Mime:
      return 2;
    case Oops_All_6s:
      return 10;
    case Brainstorm:
    case Blueprint:
      return BP_SCORE;
    default:
      break;
  }
  return 0;
}

int findNextCard(instance *inst, int ante, int * rra) {
  next_shop_item(inst, ante);
  next_shop_item(inst, ante); // two throw away calls
  for (int i = 0; i < 20; i++) {
    int score = checkNextCard(inst, ante, rra);
    if (score > 0)
      return score;
    *rra += 1;
  }
  return 0;
}

long checkAnteForShowman(instance *inst, int ante) {
  if (next_shop_item(inst, ante).value != Showman)
    if (next_shop_item(inst, ante).value != Showman)
      if (next_shop_item(inst, ante).value != Showman)
        if (next_shop_item(inst, ante).value != Showman)
          return 0;
  inst->params.showman = true;
  return 1;
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
  bool blueprint = false;
  int hitsA = 0;
  int hitsB = 0;
  int hitsC = 0;
  long bestScore = 0;
  int bestAnte = 0;
  int rerollsOnAnte = 0;

  item firstTag = RETRY;
  item secondTag = RETRY;
  int bp = 0;
  for (int a = 1; a <= 18; a++) {
    if (a > 6 && perkeoAnte == 99)
      return 0;
    if (a > 10 && observatoryAnte == 99)
      return 0;
    if (a == 14 && antimatterAnte == 99)
      return 0;

    init_unlocks(inst, a, false);
    firstTag = next_tag(inst, a);
    
    item voucher = next_voucher(inst, a);
    if (voucher == Telescope) {
      activate_voucher(inst, Telescope);
    } else if (voucher == Observatory) {
      observatoryAnte = a;
      activate_voucher(inst, Observatory);
    } else if (voucher == Blank) {
      activate_voucher(inst, Blank);
    } else if (voucher == Antimatter) {
      antimatterAnte = a;
      activate_voucher(inst, Antimatter);
    } else if (a > 1) {
      activate_voucher(inst, voucher);
    }

    if (firstTag == Double_Tag)
      dt++;
    

    if (!inst->params.showman && checkAnteForShowman(inst, a) > 0)
      inst->params.showman = true;
    else if (a < 8) {
      int dummyRRa = 0;
      if (checkNextCard(inst, a, &dummyRRa) == BP_SCORE) bp++;
      if (checkNextCard(inst, a, &dummyRRa) == BP_SCORE) bp++;
      if (checkNextCard(inst, a, &dummyRRa) == BP_SCORE) bp++;
      if (checkNextCard(inst, a, &dummyRRa) == BP_SCORE) bp++;
      if (checkNextCard(inst, a, &dummyRRa) == BP_SCORE) bp++;
      if (checkNextCard(inst, a, &dummyRRa) == BP_SCORE) bp++;
    }

    if (a >= 8 && (firstTag == Negative_Tag)) {
      int rra = 0;
      long bestRun = 0;

      // for (int i = 0; i < 3; i++) {
      //   long tg = findNextCard(inst, a, &rra);
      //   for (int t = 0; t < a + dt; t++) {
      //     int dummyRRa = 0;
      //     int te = checkNextCard(inst, a, &dummyRRa);
      //     if (te > 0) {
      //       hitsA++;
      //     }
      //     tg += te;
      //   }
      //   if (tg > bestRun) {
      //     bestRun = tg;
      //   }
      // }
      // long trigScore = bestRun;



      // next ante instead of searching
      long trigScore = 0;
      int checks = a-1+dt;

      for (int t = 0; t < 6 && t < checks; t++) {
        int dummyRRA = 0;
        int te = checkNextCard(inst, a+1, &dummyRRA);
        if (te > 0) {
          checks --;
        }
        trigScore += te;
      }
      for (int t = 0; t < 6 && t < checks; t++) {
        int dummyRRA = 0;
        int te = checkNextCard(inst, a+2, &dummyRRA);
        if (te > 0) {
          checks --;
        }
        trigScore += te;
      }
      
      if (trigScore > bestScore) {
        bestScore = trigScore;
        bestAnte = a;
        rerollsOnAnte = rra;
      }
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
          perkeoAnte = a;
        } 
      }
    }
    secondTag = next_tag(inst, a);
    if (secondTag == Double_Tag)
      dt++;
    // Anaglyph deck gains a doubletag after boss blind
    dt++;
  }

  return (bestScore)*100000 + bp*10000 + bestAnte*100 + rerollsOnAnte;
}