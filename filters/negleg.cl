#include "lib/immolate.cl"

long filter(instance *inst) {
  long score = 0;
  long firstAnte = 0;

  set_deck(inst, Ghost_Deck);
  set_stake(inst, Black_Stake);
  init_locks(inst, 1, false, false);

  for (int ante = 1; ante <= 12; ante++) {
    for (int i = 0; i < 2; i++) {
      item tag = next_tag(inst, ante);
      if (tag != Charm_Tag)
        continue;
      item arcanaPack[5];
      arcana_pack(arcanaPack, 5, inst, ante);
      for (int j = 0; j < 5; j++) {
        if (arcanaPack[j] == The_Soul) {
          jokerdata jkr = next_joker_with_info(inst, S_Soul, ante);
          if (jkr.edition == Negative) {
            score += 1;
          }
        }
      }
    }
    //burn call
    next_orbital_tag(inst);
  }

  return score;
}