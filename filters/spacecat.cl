#define CACHE_SIZE 2000


#include "lib/immolate.cl"

typedef struct {
    // Game state counters
    int tagIndex;
    bool hasSpaceman;
    bool hasBurnt;
    int blueprints;
    int brainstorms;
    int dice;
    int chads;
    int socks;
    bool hasShowman;
    bool hasLuckyCat;
    int perkeo;
    int canio;
    int triboulet;
    int yorick;
    int chicot;
    int arcanaChecks;
    int spectralChecks;
    int score;
    bool observatory;
    bool telescope;
    int observatoryAnte;
    int pareidolia;
    int dna;
    int perkeoAnte;
    
    // Game context
    instance *inst;
    int ante;
} game_state;

int scoreCard(jokerdata joker, game_state *state)
{
    int currentScore = state->score;
    int score = 0;

    if (joker.edition == Negative)
    {
        if (joker.joker == Space_Joker || joker.joker == Lucky_Cat || 
            joker.joker == Showman || joker.joker == Troubadour ||
            joker.joker == Blueprint || joker.joker == Brainstorm || joker.joker == Oops_All_6s)
        {
            score = 10000;
        }
    }

    // Update state tracking (only once per joker type unless Showman)
    if (joker.joker == Showman)
    {
        state->hasShowman = true;
        state->inst->params.showman = true; // Make sure showman parameter is set to true
    }
    else if (joker.joker == Lucky_Cat)
    {
        state->hasLuckyCat = true;
    }
    else if (joker.joker == Space_Joker)
    {
        state->hasSpaceman = true;
    }
    else if (joker.joker == Burnt_Joker)
    {
        state->hasBurnt = true;
    }
    else if (joker.joker == Blueprint)
    {
        // Always count additional Blueprints with Showman
        if (state->blueprints == 0 || state->hasShowman)
        {
            state->blueprints++;
        }
    }
    else if (joker.joker == Brainstorm)
    {
        // Always count additional Brainstorms with Showman
        if (state->brainstorms == 0 || state->hasShowman)
        {
            state->brainstorms++;
        }
    }
    else if (joker.joker == DNA)
    {
        if (state->dna == 0 || state->hasShowman)
        {
            state->dna++;
        }
    }
    else if (joker.joker == Pareidolia)
    {
        if (state->pareidolia == 0 || state->hasShowman)
        {
            state->pareidolia++;
        }
    }
    else if (joker.joker == Sock_and_Buskin)
    {
        if (state->socks == 0 || state->hasShowman)
        {
            state->socks++;
        }
    }
    else if (joker.joker == Oops_All_6s)
    {
        if (state->dice == 0 || state->hasShowman)
        {
            state->dice++;
        }
    }
    else if (joker.joker == Hanging_Chad)
    {
        if (state->chads == 0 || state->hasShowman)
        {
            state->chads++;
        }
    }

    return score;
}

void checkTelescope(instance *inst, int ante, game_state *state)
{
    if (!state->telescope && next_voucher(inst, ante) == Telescope)
    {
        state->telescope = true;
        activate_voucher(inst, Telescope);
    }
}

void checkObservatory(instance *inst, int ante, game_state *state)
{
    if (state->telescope && next_voucher(inst, ante + 1) == Observatory)
    {
        state->observatory = true;
        state->observatoryAnte = ante + 1;
        activate_voucher(inst, Observatory);
    }
}

int handle_the_soul(game_state *state) {
    jokerdata jkr = next_joker_with_info(state->inst, S_Soul, state->ante);
    if (jkr.joker == Perkeo) {
        if (state->perkeo == 0) {
            state->perkeo += 1;
            if (state->perkeoAnte > 0) state->perkeoAnte = state->ante;
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

int check_next_shopitem(game_state *state)
{
    shopitem sItem = next_shop_item(state->inst, state->ante);
    if (sItem.type == ItemType_Joker)
    {
        jokerdata joker = sItem.joker;
        int score = scoreCard(joker, state);
        return score;
    }

    return 0;
}

int check_next_pack(game_state *state)
{
    pack _pack = pack_info(next_pack(state->inst, state->ante));

    if (_pack.type == Buffoon_Pack)
    {
        int score = 0;
        jokerdata jokers[5];
        buffoon_pack_detailed(jokers, _pack.size, state->inst, state->ante);
        for (int index = 0; index < _pack.size; index++)
        {
            score += scoreCard(jokers[index], state);
        }
        return score;
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
    
    int score = 0;
    for (int index = 0; index < _pack.size; index++)
    {
        if (cards[index] == The_Soul)
        {
            score += handle_the_soul(state);
        }
    }
    
    return score;
}

int checkTagPacks(instance *inst, int ante, game_state *state)
{
    int score = 0;
    item cards[5];
    while (state->arcanaChecks > 0)
    {
        state->arcanaChecks--;
        arcana_pack(cards, 5, inst, ante);
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
        spectral_pack(cards, 5, inst, ante);
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

int checkTag(instance *inst, int ante, game_state *state)
{
    int score = 0;
    item tag = next_tag(inst, ante);
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

    return score;
}

long filter(instance *inst)
{
    set_deck(inst, Ghost_Deck);
    set_stake(inst, White_Stake);
    init_locks(inst, 1, false, true);

    game_state state = {0};
    state.blueprints = 0;
    state.brainstorms = 0;
    state.dice = 0;
    state.chads = 0;
    state.socks = 0;
    state.hasSpaceman = false;
    state.hasBurnt = false;
    state.hasLuckyCat = false;
    state.hasShowman = false;
    state.perkeo = 0;
    state.canio = 0;
    state.triboulet = 0;
    state.yorick = 0;
    state.chicot = 0;
    state.arcanaChecks = 0;
    state.spectralChecks = 0;
    state.score = 0;
    state.observatory = false;
    state.telescope = false;
    state.ante = 1;
    state.tagIndex = 0;
    state.pareidolia = 0;
    state.dna = 0;
    state.observatoryAnte = 0;
    state.perkeoAnte = 0;
    state.inst = inst;
    

    for (int ante = 1; ante <= 14; ante++)
    {
        state.ante = ante;
        init_unlocks(inst, ante, false);
        checkTelescope(inst, ante, &state);
        checkObservatory(inst, ante, &state);
        state.score += checkTag(inst, ante, &state);
        state.score += checkTag(inst, ante, &state);
        int cardSearch = ante > 2 ? ante > 4 ? ante > 6 ? ante > 8 ? ante > 10 ? 80 : 40 : 15 : 8 : 6 : 4;
        for (int i = 0; i < cardSearch; i++)
        {
            state.score += check_next_shopitem(&state);
        }
        state.score += check_next_pack(&state);
        state.score += check_next_pack(&state);
        state.score += check_next_pack(&state);
        state.score += check_next_pack(&state);
        if (ante > 1) {
            state.score += check_next_pack(&state);
            state.score += check_next_pack(&state);
        }
        state.score += checkTagPacks(inst, ante, &state);

        if (ante > 1 && state.perkeo == 0) return 0;

        if (ante > 4) {
            
            if (state.blueprints + state.brainstorms < 1) return 0;
            
            // Check for Lucky Cat after ante 6
            if (ante > 6 && !state.hasLuckyCat) break;
            
            // Need at least one Oops by ante 8
            if (ante > 8 && state.dice < 1) break;
        } 
        
        if (ante > 10) {
            // Stricter requirements for later antes
            if (state.dice < 2) break;
        }
    }

    int composite = 
        state.brainstorms+
        state.blueprints+
        state.dna+
        state.chads+
        state.socks+
        state.perkeo+
        state.canio+
        state.triboulet+
        state.yorick+
        state.chicot+
        state.pareidolia;
                

    return state.score + (        
                                    1000000000*composite +
                                    100000000*state.brainstorms + 
                                    10000000*state.blueprints + 
                                    1000000*state.dna + 
                                    100000*state.canio
// Negatives we want=               10000*
// negative legendaries=            1000*
// negative skip tag first blind=   100*
// negative skip tag second blind=  10*
// random negatives=                1*
    );
    // max value: 18446744073709551615
    // test score 100000000000000
   
                         
}