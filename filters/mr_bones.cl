#include "lib/immolate.cl"
long filter(instance* inst) {
    const int score_lookup[] = {
        [Troubadour] = 1, [Juggler] = 1,
        [Sock_and_Buskin] = 10, [Hanging_Chad] = 10,
        [Baron] = 100, [Mime] = 100,
        [Oops_All_6s] = 1000, 
        [Brainstorm] = 10000, [Blueprint] = 10000};
  long score = 0;
  set_deck(inst, Anaglyph_Deck);
  init_locks(inst, 1, false, true);
  init_unlocks(inst, 1, false);
  if (next_shop_item(inst, 1).value != Showman)
    if (next_shop_item(inst, 1).value != Showman)
        if (next_shop_item(inst, 1).value != Showman)
            if (next_shop_item(inst, 1).value != Showman)
                return 0;
  inst->params.showman = true;
  for (long a = 2; a < 12; a++) {
    init_unlocks(inst, a, false);
    if (a < 8) continue;
    if (next_tag(inst, a) == Negative_Tag) {

        int checks = a-1;
        for (int i = 0; i < 6 && checks > 0; i++) {
            shopitem _item = next_shop_item(inst, a+1);
            score += score_lookup[_item.value];
            if (_item.type == ItemType_Joker && _item.joker.edition == No_Edition)
                checks--;
        }
        for (int i = 0; i < 6 && checks > 0; i++) {
            shopitem _item = next_shop_item(inst, a+2);
            score += score_lookup[_item.value];
            if (_item.type == ItemType_Joker && _item.joker.edition == No_Edition)
                checks--;
        }
        for (int i = 0; i < 6 && checks > 0; i++) {
            shopitem _item = next_shop_item(inst, a+3);
            score += score_lookup[_item.value];
            if (_item.type == ItemType_Joker && _item.joker.edition == No_Edition)
                checks--;
        }
       
        return score*100 + a;
    }
  }
  return 0;
}
