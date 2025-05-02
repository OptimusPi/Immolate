#include "lib/immolate.cl"
#define CACHE_SIZE 128
#define FIXED_FILTER_CUTOFF 1

long testScore(instance* inst, int ante) {
  long score = 0;
  shopitem _item = next_shop_item(inst, ante);
  for (int i = 0; i < 10; i++) {
    if (_item.type == ItemType_Joker && _item.joker.edition == Negative) 
      score += 1000;
    if (_item.type == ItemType_Joker && _item.joker.edition == No_Edition) break;
    _item = next_shop_item(inst, ante);
  }
  
  if (_item.type != ItemType_Joker || _item.joker.edition != No_Edition) return 0;
  
  if (_item.value == Blueprint) score = 10;
  else if (_item.value == Brainstorm) score = 10;
  else if (_item.value == Oops_All_6s) score = 3;
  else if (_item.value == Space_Joker) score = 1;
  else if (_item.value == Sock_and_Buskin) score = 2;
  else if (_item.value == Hanging_Chad) score = 1;
  else if (_item.value == Bloodstone) score = 2;
  else if (_item.value == Lucky_Cat) score = 2 ;
  else if (_item.value == Burnt_Joker) score = 1;
  else if (_item.value == Baron) score = 2;
  else if (_item.value == Mime) score = 2;
  else { 
    return score;
  }
  if (_item.joker.edition == Negative) {
    return 10000+score;
  }
  return score;
}

long filter(instance *inst) {
  long s = 0;
  int dt = 0;
  set_deck(inst, Anaglyph_Deck);
  set_stake(inst, White_Stake);
  init_locks(inst, 1, false, false);
  for (int a = 1; a <= 8; a++) {
    init_unlocks(inst, a, false);
    item firstTag = next_tag(inst, a);
    item secondTag = next_tag(inst, a);

    if (a == 1) {
      shopitem _item = next_shop_item(inst, a);
      shopitem _item2 = next_shop_item(inst, a);
      if (_item.value != Showman && _item2.value != Showman) {
          return 0;
      }
      if (firstTag != Charm_Tag && secondTag != Charm_Tag) {
          return 0;
      }
      item arcanaPack[5];
      arcana_pack(arcanaPack, 5, inst, true);
      bool soul = false;
      for (int i = 0; i < 5; i++) {
          if (arcanaPack[i] == The_Soul) {
              soul = true;
          }
      }
      item jkr = next_joker(inst, S_Soul, 1);
      if (!soul || jkr != Perkeo) {
          return 0;
      }
    }

    if (firstTag == Double_Tag){
      dt ++;
    }

    if (firstTag == Negative_Tag) {
      long z = 0;
      // I imagine I could skip this many times to try to line up a negative.
      for (int skip = 0; z == 0 && skip < 4; skip++) {
        z += testScore(inst, a);
      }

      // if I skipped to a score, (start at z(1) if scored a card) then use up all the double tags
      // that we've kept track of.
      for (int w = 1; w < dt; w++) {
        z += testScore(inst, a);
      }
      
      // dont waste double-tags if no good jokers ahead
      if (z > 0)
        dt = 0; // all double tags trigger. 
      s += z;
    }
    

    if (secondTag == Double_Tag){
      dt ++;
    }
    if (secondTag == Negative_Tag) {
      long z = 0;
      z += testScore(inst, a);
      // can't line up the big blind skip tag.
      for (int w = 0; w < dt; w++) {
        z += testScore(inst, a);
      }
      // dont waste double-tags if no good jokers ahead
      if (z > 0)
        dt = 0; // all double tags trigger. 
      s += z;
    }

    // Anaglyph deck gains a doubletag after boss blind
    dt++;
  }
  return s;
}