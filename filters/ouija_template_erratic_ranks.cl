#include "lib/ouija.cl"

// Ultra-optimized Erratic Deck rank counter inspired by Immolate's approach
void ouija_filter(instance *inst, __constant OuijaConfig *config, __global OuijaResult *result) {
  // Always use Erratic Deck - that's what this filter is for
  set_deck(inst, Erratic_Deck);

  // Initialize result
  result->TotalScore = 0;
  result->NegativeJokers = 0;
  
  // Initialize score array for all 13 ranks (2-A)
  int16 rank_counts = (int16)(0);
  
  // Get deck and process ranks
  item deck[52];
  init_deck(inst, deck);
  
  // Count occurrences of each rank
  for (int i = 0; i < 52; i++) {
    // Subtract _2 to get 0-based index (2=0, 3=1, ..., A=12)
    int rank_idx = rank(deck[i]) - _2;
    rank_counts[rank_idx]++;
  }
  
  // Now map the rank counts to the wants in the config
  int num_wants = min(config->numWants, 16);
  for (int w = 0; w < num_wants; w++) {
    // For each want that is a rank, get its count
    if (config->Wants[w].value >= _2 && config->Wants[w].value <= _A) {
      int rank_idx = config->Wants[w].value - _2;
      result->ScoreWants[w] = rank_counts[rank_idx];
      
      // Update total score if this is higher
      if (result->ScoreWants[w] > result->TotalScore) {
        result->TotalScore = result->ScoreWants[w];
      }
    }
  }
  
  return;
}
