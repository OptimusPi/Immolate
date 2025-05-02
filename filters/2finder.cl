#include "lib/immolate.cl"

long filter(instance* inst) {
  set_deck(inst, Erratic_Deck);
  init_locks(inst, 1, false, false);
  item deck[52];
  init_deck(inst, deck);
  long twos = 0;
  bool perkeo = false;
  __attribute__((opencl_unroll_hint(52)))
  for (int i = 0; i < 52; i++) {
    if (rank(deck[i]) == _2) twos++;
  }
  if (twos < 8) return 0;
  if (next_tag(inst, 1) == Charm_Tag || next_tag(inst, 1) == Charm_Tag)
  {
    item cards[5];
    arcana_pack(cards, 5, inst, 1);
    for (int i = 0; i < 5; i++)
    {
      if (cards[i] == The_Soul){
        item value = next_joker(inst, S_Soul, 1);
        if (value == Perkeo) {
            perkeo = true;
        }
      }
    }
  }
  else if (next_tag(inst, 2) == Charm_Tag || next_tag(inst, 2) == Charm_Tag)
  {
    item cards[5];
    arcana_pack(cards, 5, inst, 2);
    for (int i = 0; i < 5; i++)
    {
      if (cards[i] == The_Soul){
        item value = next_joker(inst, S_Soul, 2);
        if (value == Perkeo) {
            perkeo = true;
        }
      }
    }
  }

  if (perkeo == false) return 0;
  bool hack = true;
  bool wee = true;
  if (next_shop_item(inst, 1).value != Hack)
    if (next_shop_item(inst, 1).value != Hack)
      if (next_shop_item(inst, 1).value != Hack)
        if (next_shop_item(inst, 1).value != Hack)
          hack=false;
  if (next_shop_item(inst, 2).value != Wee_Joker)
    if (next_shop_item(inst, 2).value != Wee_Joker)
      if (next_shop_item(inst, 2).value != Wee_Joker)
        if (next_shop_item(inst, 2).value != Wee_Joker)
          wee=false;
  if (perkeo == false) return 0;
  long score = twos;
  score += perkeo == true ? 10000 : 0;
  score += wee == true ? 1000 : 0;
  score += hack == true ? 100 : 0;
  return score;
}