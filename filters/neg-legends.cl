
#include "lib/immolate.cl"

typedef struct {
    // Game state counters
    int tagIndex;
    int blueprints;
    int brainstorms;
    bool hasShowman;
    int perkeo;
    int canio;
    int triboulet;
    int yorick;
    int chicot;
    int score;
    int spectralChecks;
    int arcanaChecks;
    
    // Game context
    instance *inst;
    int ante;
} game_state;

int handle_the_soul(game_state *state) {
    jokerdata jkr = next_joker_with_info(state->inst, S_Soul, state->ante);
    if (jkr.joker == Perkeo) {
        if (state->perkeo == 0) {
            state->perkeo += 1;
            if (jkr.edition == Negative) {
                return 1000;
            }
        }
    } else if (jkr.joker == Canio) {
        if (state->canio == 0) {
            state->canio += 1;
            if (jkr.edition == Negative) {
                return 1000;
            }
        }
    } else if (jkr.joker == Triboulet) {
        if (state->triboulet == 0) {
            state->triboulet += 1;
            if (jkr.edition == Negative) {
                return 1000;
            }
        }
    } else if (jkr.joker == Yorick) {
        if (state->yorick == 0) {
            state->yorick += 1;
            if (jkr.edition == Negative) {
                return 1000;
            }
        }
    } else if (jkr.joker == Chicot) {
        if (state->chicot == 0) {
            state->chicot += 1;
            if (jkr.edition == Negative) {
                return 1000;
            }
        }
    }
    return 0;
}

int check_next_pack(game_state *state)
{
    pack _pack = pack_info(next_pack(state->inst, state->ante));

    if (_pack.type == Buffoon_Pack)
    {
        return 0;
    }
    
    // Handle other pack types
    item cards[5];
    if (_pack.type == Spectral_Pack)
    {
        state->spectralChecks--;
        spectral_pack(cards, _pack.size, state->inst, state->ante);
    }
    else if (_pack.type == Arcana_Pack)
    {
        state->arcanaChecks--;
        arcana_pack(cards, _pack.size, state->inst, state->ante);
    }
    else {
        // Skip Standard Pack
        return 0;
    }
    
    for (int index = 0; index < _pack.size; index++)
    {
        if (cards[index] == The_Soul)
        {
            int score = handle_the_soul(state);
            return score;
        }
    }
    
    return 0;
}

int checkTagPacks(instance *inst, game_state *state)
{
    int score = 0;
    item cards[5];
    while (state->arcanaChecks > 0)
    {
        state->arcanaChecks--;
        arcana_pack(cards, 5, inst, state->ante);
        for (int index = 0; index < 5; index++)
        {
            if (cards[index] == The_Soul)
            {
                score += handle_the_soul(state);
            }
        }
    }
    while (state->spectralChecks > 0)
    {
        state->spectralChecks--;
        spectral_pack(cards, 5, inst, state->ante);
        for (int index = 0; index < 5; index++)
        {
            if (cards[index] == The_Soul)
            {
                score += handle_the_soul(state);
            }
        }
    }
    return score;
}

int checkTag(instance *inst, game_state *state)
{
    int score = 0;
    item tag = next_tag(inst, state->ante);
    if (tag == Charm_Tag)
    {
        state->arcanaChecks++;
    }
    else if (tag == Ethereal_Tag)
    {
        state->spectralChecks++;
    }
    else if (tag == Negative_Tag)
    {
        score = state->tagIndex == 0 ? 100 : 10;
    }

    state->tagIndex++;
    if (state->tagIndex == 2) {
        state->tagIndex = 0;
        next_orbital_tag(inst); //burn function call on Boss Blind
    }

    return 0;
   // return score;
}

long filter(instance *inst)
{
    set_deck(inst, Ghost_Deck);
    set_stake(inst, Black_Stake);
    init_locks(inst, 1, false, true);

    game_state state = {0};
    state.blueprints = 0;
    state.brainstorms = 0;
    state.hasShowman = false;
    state.perkeo = 0;
    state.canio = 0;
    state.triboulet = 0;
    state.yorick = 0;
    state.chicot = 0;
    state.arcanaChecks = 0;
    state.spectralChecks = 0;
    state.score = 0;
    state.ante = 1;
    state.tagIndex = 0;
    state.inst = inst;
    state.ante = 1;
    init_unlocks(inst, 1, false);
    state.score += checkTag(inst, &state);
    state.score += checkTag(inst, &state);
    state.score += check_next_pack(&state);
    state.score += check_next_pack(&state);
    state.score += check_next_pack(&state);
    state.score += check_next_pack(&state);
    state.score += checkTagPacks(inst, &state);
    state.ante = 2;
    init_unlocks(inst, 2, false);
    state.score += checkTag(inst, &state);
    state.score += checkTag(inst, &state);
    state.score += check_next_pack(&state);
    state.score += check_next_pack(&state);
    state.score += check_next_pack(&state);
    state.score += check_next_pack(&state);
    state.score += checkTagPacks(inst, &state);
    state.ante = 3;
    init_unlocks(inst, 3, false);
    state.score += checkTag(inst, &state);
    state.score += checkTag(inst, &state);
    state.score += check_next_pack(&state);
    state.score += check_next_pack(&state);
    state.score += check_next_pack(&state);
    state.score += check_next_pack(&state);
    state.score += checkTagPacks(inst, &state);
    return state.score;
}