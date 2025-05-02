#ifndef DESIRES_H
#define DESIRES_H

#include "immolate.h"

typedef struct {
    item Needs[10]; // Array of required items
    bool ScoreNeeds[10]; // Whether each need has been scored
    item Wants[10]; // Array of optional items
    int ScoreWants[10]; // Scores for each want
    int ante; // Ante value
    bool requirePerkeo; // Whether Perkeo is required
    int perkeoAnte; // Ante for Perkeo
    bool requireShowman; // Whether Showman is required
    int showmanAnte; // Ante for Showman
} desires;

#endif // DESIRES_H