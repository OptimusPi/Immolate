// Searches for an Erratic Deck seed with lots of a rank
#include "lib/immolate.cl"
long filter(instance *inst) {
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
  if (!perkeo) return 0;
  long score = 0;
  int hack = 0;
  int wee = 0;
  int blueprintOrBrainstorm = 0;
  int showman = 0;
  for (int i = 1; i <= 8; i++) {
    shopitem _item = next_shop_item(inst, i);
    if (_item.type == ItemType_Joker && _item.joker.edition == Negative) score++;
    hack += _item.value == Hack ? 1 : 0;
    wee += _item.value == Wee_Joker ? 1 : 0;
    showman += _item.value == Showman ? 1 : 0;
    blueprintOrBrainstorm += _item.value == Blueprint || _item.value == Brainstorm ? 1 : 0;
    if (showman == 0) return 0;
    if (i == 2 && wee == 0) return 0;
    if (i == 3 && hack == 0) return 0;
  }
  if (wee == 0 || hack == 0) return 0;
  return twos*100 + blueprintOrBrainstorm*10 + score;
}