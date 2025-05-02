
#define CACHE_SIZE 1000
#include "lib/immolate.cl"

typedef struct {
    // Game state counters
    int tagIndex;
    int blueprints;
    int brainstorms;
    int dice;
    int chads;
    int socks;
    bool hasShowman;
    int perkeo;
    int canio;
    int triboulet;
    int yorick;
    int chicot;
    int arcanaChecks;
    int spectralChecks;
    int score;
    bool observatory;
    int observatoryAnte;
    bool telescope;
    int cardChecks;
    int cardChecksThisAnte;
    
    // Game context
    instance *inst;
    int ante;
} game_state;

int scoreCard(jokerdata joker, game_state *state)
{
    int currentScore = state->score;
    int score = 0;
    state->cardChecks++;
    state->cardChecksThisAnte++;

    if (joker.joker == Showman)
    {
        state->hasShowman = true;
        state->inst->params.showman = true;
        if (joker.edition == Negative)
        {
            // Only for debugging
            int newScore = currentScore + 10000;
            printf("[Ante: %i] Score %d -> %d after getting negative showman\n", state->ante, currentScore, newScore);
            score = 10000; // 100 points for negatives of special cards
        }
    }
    else if (joker.joker == Blueprint)
    {
        if (state->blueprints == 0 || state->hasShowman)
        {
            state->blueprints++;
            if (joker.edition == Negative)
            {
                int newScore = currentScore + 10000;
                printf("[Ante: %i] Score %d -> %d after getting negative blueprint\n", state->ante, currentScore, newScore);
                score = 10000; // 100 points for negatives of special cards
            }
        }
    }
    else if (joker.joker == Brainstorm)
    {
        if (state->brainstorms == 0 || state->hasShowman)
        {
            state->brainstorms++;
            if (joker.edition == Negative)
            {
                int newScore = currentScore + 10000;
                printf("[Ante: %i] Score %d -> %d after getting negative brainstorm\n", state->ante, currentScore, newScore);
                score = 10000; // 100 points for negatives of special cards
            }
        }
    } 
    else if (joker.joker == Sock_and_Buskin)
    {
        if (state->socks == 0 || state->hasShowman)
        {
            state->socks++;
            if (joker.edition == Negative)
            {
                int newScore = currentScore + 10000;
                printf("[Ante: %i] Score %d -> %d after getting negative sock and buskin\n", state->ante, currentScore, newScore);
                score = 10000; // 100 points for negatives of special cards
            }
        }
    }
    else if (joker.joker == Oops_All_6s)
    {
        if (state->dice == 0 || state->hasShowman)
        {
            state->dice++;
            if (joker.edition == Negative)
            {
                int newScore = currentScore + 10000;
                printf("[Ante: %i] Score %d -> %d after getting negative oops all 6s\n", state->ante, currentScore, newScore);
                score = 10000; // 100 points for negatives of special cards
            }
        }
    }
    else if (joker.joker == Hanging_Chad)
    {
        if (state->chads == 0 || state->hasShowman)
        {
            state->chads++;
            if (joker.edition == Negative)
            {
                int newScore = currentScore + 10000;
                printf("[Ante: %i] Score %d -> %d after getting negative hanging chad\n", state->ante, currentScore, newScore);
                score = 10000; // 100 points for negatives of special cards
            }
        }
    } else {
        if (joker.edition == Negative)
        {
            int newScore = currentScore + 1;
            printf("[Ante: %i] Score %d -> %d after getting negative random joker I dont care about\n", state->ante, currentScore, newScore);
            score = 1; // 1 point for negatives we "don't care about"
        }
        return 0;
    }

    if (score > 0)
    {
        printf("(Card checks this ante is: %d)\n", state->cardChecksThisAnte);
        printf("(Card checks total: %d)\n", state->cardChecks);  
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
            if (jkr.edition == Negative) {
                int newScore = state->score + 1000;
                printf("The_Soul: [Ante: %i] Score %d -> %d after getting negative perkeo\n", state->ante, (state->score), newScore);
                return 1000;
            }
        }
    } else if (jkr.joker == Canio) {
        if (state->canio == 0) {
            state->canio += 1;
            if (jkr.edition == Negative) {
                int newScore = state->score + 1000;
                printf("The_Soul: [Ante: %i] Score %d -> %d after getting negative canio\n", state->ante, (state->score), newScore);
                return 1000;
            }
        }
    } else if (jkr.joker == Triboulet) {
        if (state->triboulet == 0) {
            state->triboulet += 1;
            if (jkr.edition == Negative) {
                int newScore = state->score + 1000;
                printf("The_Soul: [Ante: %i] Score %d -> %d after getting negative triboulet\n", state->ante, (state->score), newScore);
                return 1000;
            }
        }
    } else if (jkr.joker == Yorick) {
        if (state->yorick == 0) {
            state->yorick += 1;
            if (jkr.edition == Negative) {
                int newScore = state->score + 1000;
                printf("!![Ante: %i] Score %d -> %d after getting negative perkeo\n", state->ante, (state->score), newScore);
                return 1000;
            }
        }
    } else if (jkr.joker == Chicot) {
        if (state->chicot == 0) {
            state->chicot += 1;
            if (jkr.edition == Negative) {
                int newScore = state->score + 1000;
                printf("The_Soul: [Ante: %i] Score %d -> %d after getting negative chicot\n", state->ante, (state->score), newScore);
                return 1000;
            }
        }
    }

    if (jkr.edition == Negative) {
        text s_str = s_to_string(&(state->inst->seed));
        printf("\7Found Negative Legendary Joker in Seed: %s Ante: %i\n", s_str.str, state->ante);
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
        if (score > 0)
        {
            int oldScore = state->score;
            int newScore = state->score + score;
            printf("[Shop Joker](Ante: %i) check_next_shopitem detected score change from %d to %d\n", state->ante, oldScore, (newScore));
        }
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
        if (score > 0)
        {
            printf("[Buffoon_Pack](Ante: %i) check_next_pack() detected score change from %d to %d\n", state->ante, state->score, (state->score + score));
        }
        return score;
    }
    
    // Handle other pack types
    item cards[5];
    if (_pack.type == Spectral_Pack)
    {
        spectral_pack(cards, _pack.size, state->inst, state->ante);
    }
    else if (_pack.type == Arcana_Pack)
    {
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
            if (score > 0)
            {
                printf("[Spectral_Pack] check_next_pack() detected score change from %d to %d\n", state->score, score);
                return score;
            }
        }
    }
    
    return 0;
}

int checkTag(instance *inst, int ante, game_state *state)
{
    int score = 0;
    item tag = next_tag(inst, ante);
    if (tag == Charm_Tag)
    {
        state->arcanaChecks++;
        score = 1;
    }
    else if (tag == Ethereal_Tag)
    {
        state->spectralChecks++;
        score = 1;
    }
    else if (tag == Negative_Tag)
    {
        score = 100;
    }

    state->tagIndex++;
    if (state->tagIndex == 2) {
        state->tagIndex = 0;
        next_orbital_tag(inst); //burn function call on Boss Blind
        return 0;
    }

    return score;
}

long filter(instance *inst)
{
    set_deck(inst, Ghost_Deck);
    set_stake(inst, Black_Stake);
    init_locks(inst, 1, false, true);

    game_state state = {0};
    state.blueprints = 0;
    state.brainstorms = 0;
    state.dice = 0;
    state.chads = 0;
    state.socks = 0;
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
    state.cardChecks = 0;
    state.cardChecksThisAnte = 0;
    state.ante = 1;
    state.tagIndex = 0;
    state.observatoryAnte = 0;
    state.inst = inst;

    for (int ante = 1; ante <= 12; ante++)
    {
        printf("Starting Score This Ante: %d\n", state.score);
        printf("\tStarting telescope observatory search\n");

        checkTelescope(inst, ante, &state);
        checkObservatory(inst, ante, &state);
        checkTag(inst, ante, &state);
        checkTag(inst, ante, &state);

        int cardChecks = ante*6;
        printf("[Ante %i] Searching %i shop items... %i\n", ante, cardChecks);
        for (int i = 0; i < cardChecks; i++)
        {
            state.score += check_next_shopitem(&state);
        }

        printf("Searching packs for ante... %i\n", ante);
        state.ante = ante;
        state.cardChecksThisAnte = 0;
        init_unlocks(inst, ante, false);
        state.score += check_next_pack(&state);
        state.score += check_next_pack(&state);
        state.score += check_next_pack(&state);
        state.score += check_next_pack(&state);
        if (ante > 1) {
            state.score += check_next_pack(&state);
            state.score += check_next_pack(&state);
        }
    }

    // Negatives we want=10000, negative legendaries=1000, negative skip tag=100, random negatives=1
    return state.score;
}