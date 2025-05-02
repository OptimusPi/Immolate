#include "lib/immolate.cl"

int check_next_pack(instance *inst, int ante, ) {
  pack _pack = pack_info(next_pack(inst, ante));
  if (_pack.type == Buffoon_Pack) {
    int score = 0;
    jokerdata jokers[5];
    buffoon_pack_detailed(jokers, _pack.size, inst, ante);
    for (int index = 0; index < _pack.size; index++) {
      if (jokers[index].edition == Negative) {
        if (jokers[index].joker == Perkeo) {
          score += 100;
        } else if (jokers[index].joker == Canio) {
          score += 10;
        } else if (jokers[index].joker == Triboulet) {
          score += 1;
        }
        return 100;
      }
    }
    return score;
  }
  return 0;
}

int check_next_shopitem(instance *inst, int ante) {
  shopitem sItem = next_shop_item(inst, ante);
  if (sItem.type == ItemType_Spectral) {
    return 10;
  } else if (sItem.type == ItemType_Joker) {
    if (sItem.joker.edition == Negative) {
      return 100;
    }
  } else {
    return 1;
  }
  return 0;
}

long filter(instance *inst) {
  int souls = 0;
  int canio = 0;
  int yorick = 0;
  int perkeo = 0;
  long score = 0;
  bool telescope = false;
  bool observatory = false;
  set_deck(inst, Ghost_Deck);
  set_stake(inst, Black_Stake);
  init_locks(inst, 1, false, false);

  for (int ante = 1; ante < 8; ante++) {
    init_unlocks(inst, ante, false);
    if (telescope && next_voucher(inst, ante + 1) == Observatory) {
        observatory = true;
      }
    if (next_voucher(inst, ante) == Telescope) {
      telescope = true;
      activate_voucher(inst, Telescope);
    }
  }
  if (!observatory) {
    return 0;
  }

  for (int ante = 1; ante <= 8; ante++) {
    init_unlocks(inst, ante, false);
    item tag = next_tag(inst, ante);
    item tag2 = next_tag(inst, ante);
    int spectralChecks = 0;
    int arcanaChecks = 0;
    if (tag == Charm_Tag)
      arcanaChecks += 1;
    if (tag2 == Charm_Tag)
      arcanaChecks += 1;
    if (tag == Negative_Tag)
      score += 1400;
    if (tag2 == Negative_Tag)
      score += 700;

    for (int i = 0; i < arcanaChecks; i++) {
      item arcanaPack[5];
      arcana_pack(arcanaPack, 5, inst, ante);

      for (int j = 0; j < 5; j++) {
        if (arcanaPack[j] == The_Soul) {
          souls += 1;
          jokerdata jkr = next_joker_with_info(inst, S_Soul, ante);
          if (jkr.edition == Negative) {
            if (jkr.joker == Perkeo) {
              perkeo += 1;
            }
            if (jkr.joker == Canio) {
              canio += 1;
            }
          }
        }
      }
    }

    score += check_next_shopitem(inst, ante);
    score += check_next_shopitem(inst, ante);
    score += check_next_pack(inst, ante);
    score += check_next_pack(inst, ante);
    score += check_next_shopitem(inst, ante);
    score += check_next_shopitem(inst, ante);
    score += check_next_pack(inst, ante);
    score += check_next_pack(inst, ante);
    if (ante == 1)
      continue;
    score += check_next_shopitem(inst, ante);
    score += check_next_shopitem(inst, ante);
    score += check_next_pack(inst, ante);
    score += check_next_pack(inst, ante);
    score += check_next_shopitem(inst, ante);
    score += check_next_shopitem(inst, ante);
    for (int ext = 0; ext < ante; ext++) {
      score += check_next_shopitem(inst, ante);
      score += check_next_shopitem(inst, ante);
    }
    if (ante == 2 && perkeo == 0)
        return 0;
    if (ante == 3 && canio == 0)
        return 0;
  }

  return score;
}