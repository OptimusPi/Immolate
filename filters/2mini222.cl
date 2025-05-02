#include "lib/immolate.cl"

long filter(instance* inst) {
  set_deck(inst, Erratic_Deck);
  init_locks(inst, 1, false, false);
  item deck[52];
  init_deck(inst, deck);
  long twos = 0;
  for (int i = 0; i < 52; i++) {
    if (rank(deck[i]) == _2) twos++;
  }
  if (twos < 15) return 0;
  bool wee = false;
  bool hack = false;
  int dt = 0;
  for (int ante = 1; ante <= 8; ante++)
  {
    init_unlocks(inst, ante, false);
    if (next_tag(inst, ante) == Double_Tag) dt ++;
    if (next_tag(inst, ante) == Double_Tag) dt ++;
    next_orbital_tag(inst);
    __attribute__((opencl_unroll_hint(4)))
    for (int i = 0; i < 4; i++) {
      shopitem _shopItem = next_shop_item(inst, ante);
      if (_shopItem.type == ItemType_Joker && _shopItem.joker.edition == No_Edition) {
        if (_shopItem.joker.joker == Hack) hack = true;
        else if (_shopItem.joker.joker == Wee_Joker) wee = true;
      }
    }
    __attribute__((opencl_unroll_hint(2)))
    for (int i = 0; i < 4; i++) {
      pack _pack = next_pack(inst, ante);
      if (_shopItem.type == ItemType_Joker && _shopItem.joker.edition == No_Edition) {
        if (_shopItem.joker.joker == Hack) hack = true;
        else if (_shopItem.joker.joker == Wee_Joker) wee = true;
      }
    }
  }
  return twos;
}