#include "lib/immolate.cl"

int check_next_pack(instance *inst, int ante, bool *ankh, bool *soda,
                    bool *perkeo) {
  pack _pack = pack_info(next_pack(inst, ante));

  if (_pack.type == Buffoon_Pack) {
    int score = 0;
    jokerdata jokers[5];
    buffoon_pack_detailed(jokers, _pack.size, inst, ante);
    for (int index = 0; index < _pack.size; index++) {
      if (jokers[index].joker == Diet_Cola)
        *soda = true;
      if (jokers[index].edition == Negative)
        return 1;
    }
  } else {
    item cards[5];
    if (_pack.type == Arcana_Pack) {
      arcana_pack(cards, _pack.size, inst, ante);
    } else if (_pack.type == Spectral_Pack) {
      spectral_pack(cards, _pack.size, inst, ante);
    } else {
      return 0;
    }
    for (int c = 0; c < _pack.size; c++) {
      if (cards[c] == The_Soul) {
        jokerdata jkr = next_joker_with_info(inst, S_Soul, ante);
        if (jkr.joker == Perkeo) {
          *perkeo = true;
        }
        if (jkr.edition == Negative) {
          return 1;
        }
      } else {
      }
    }
  }
  return 0;
}

int check_next_shopitem(instance *inst, int ante, bool *ankh, bool *soda,
                        bool *perkeo) {
  shopitem sItem = next_shop_item(inst, ante);
  if (sItem.type == ItemType_Spectral) {
    if (sItem.value == Ankh) {
      *ankh = true;
    } else if (sItem.value == The_Soul) {
      jokerdata jkr = next_joker_with_info(inst, S_Soul, ante);
      if (jkr.joker == Perkeo) {
        *perkeo = true;
      }
      if (jkr.edition == Negative) {
        return 1;
      }
    }
  } else if (sItem.type == ItemType_Joker) {
    if (sItem.joker.edition == Negative) {
      return 1;
    } else if (sItem.joker.joker == Diet_Cola) {
      *soda = true;
    }
  }
  return 0;
}

long filter(instance *inst) {
  bool perkeo = false;
  int negTags = 0;
  long score = 0;
  bool ankh = false;
  bool soda = false;
  set_deck(inst, Ghost_Deck);
  set_stake(inst, Black_Stake);

  for (int ante = 1; ante <= 8; ante++) {
    init_unlocks(inst, ante, false);
    item tag = next_tag(inst, ante);
    item tag2 = next_tag(inst, ante);
    if (tag == Negative_Tag) {
      negTags += 1;
      score += 10;
    }
    if (tag2 == Negative_Tag) {
      negTags += 1;
      score += 1;
    }

    score += check_next_shopitem(inst, ante, &ankh, &soda, &perkeo);
    score += check_next_shopitem(inst, ante, &ankh, &soda, &perkeo);
    score += check_next_pack(inst, ante, &ankh, &soda, &perkeo);
    score += check_next_pack(inst, ante, &ankh, &soda, &perkeo);
    score += check_next_shopitem(inst, ante, &ankh, &soda, &perkeo);
    score += check_next_shopitem(inst, ante, &ankh, &soda, &perkeo);
    score += check_next_pack(inst, ante, &ankh, &soda, &perkeo);
    score += check_next_pack(inst, ante, &ankh, &soda, &perkeo);
    score += check_next_shopitem(inst, ante, &ankh, &soda, &perkeo);
    score += check_next_shopitem(inst, ante, &ankh, &soda, &perkeo);
    if (ante > 3) {
      if (!soda || !ankh || !perkeo)
        return 0;
    }
  }

  return score;
}