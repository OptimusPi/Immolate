#include "lib/ouija.cl"

void ouija_filter(instance *inst, __constant OuijaConfig *config, __global OuijaResult *result) {
  result->NaturalNegativeJokers = 0;
  int maxAnte = config->maxSearchAnte == 0 ? 8 : config->maxSearchAnte;
  int max = 8;
  
  int bestScore = 0;
  for (int ante = 1; ante <= maxAnte; ante++) {
    int anteScore = 0;
    int hp = 1;
    for (int i = 0; i < max && hp > 0; i++) {
      if (next_joker_edition(inst, S_Shop, ante) == Negative) {
        anteScore++;
      } else {
        hp--;
      }
    }
    if (anteScore > bestScore) {
      bestScore = anteScore;
    }
    result->NaturalNegativeJokers = bestScore;
  }
  if (result->NaturalNegativeJokers == 0) {
    result->TotalScore = 0;
    return;
  } else {
    result->TotalScore += result->NaturalNegativeJokers;
  }
  
  // Convert seed to string
  text s_str = s_to_string(&inst->seed);
  
  // Copy seed string efficiently 
  #pragma unroll
  for (int i = 0; i < 9; i++) {
    result->seed[i] = s_str.str[i];
  }
}