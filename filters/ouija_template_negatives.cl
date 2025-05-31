#include "lib/ouija.cl"

void ouija_filter(instance *inst, __constant OuijaConfig *config, __global OuijaResult *result) {
  result->NegativeJokers = 0;
  int maxAnte = config->maxSearchAnte == 0 ? 8 : config->maxSearchAnte;
  for (int ante = 1; ante <= maxAnte; ante++) {
    int shopCount = (ante == 1) ? 4 : 6;
    for (int i = 0; i < shopCount; i++) {
      shopitem shItem = next_shop_item(inst, ante);
      if (shItem.type == ItemType_Joker && shItem.joker.edition == Negative) {
        result->NegativeJokers++;
      }
    }
  }
  
  // Convert seed to string
  text s_str = s_to_string(&inst->seed);
  
  // Copy seed string efficiently 
  #pragma unroll
  for (int i = 0; i < 9; i++) {
    result->seed[i] = s_str.str[i];
  }
}