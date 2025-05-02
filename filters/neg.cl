// Legendary jokers and negatives high score by NAte
// Why doesnt this work? IT was working but I changed it a tiny bit now it doesnt work

#include "lib/immolate.cl"

int scoreCard(jokerdata joker, int ante)
{
    int score = 0;
    if (joker.joker == Blueprint || joker.joker == Brainstorm)
    {
        score ++;
    }
    if (joker.edition == Negative)
        return score + 100;
    if (joker.edition == Polychrome)
        return score + 10;
    return 0;      
}

int check_next_pack(instance *inst, int ante, int *arcanaChecks, int *spectralChecks, int *perkeo, int *canio)
{
    pack _pack = pack_info(next_pack(inst, ante));

    if (_pack.type == Buffoon_Pack)
    {
        int score = 0;
        jokerdata jokers[5];
        buffoon_pack_detailed(jokers, _pack.size, inst, ante);
        for (int index = 0; index < _pack.size; index++)
        {
            score += scoreCard(jokers[index]);
        }
        return score;
    }
    else
    {
        item cards[5];
        if (_pack.type == Spectral_Pack)
        {
            if (*spectralChecks > 0)
            {
                *spectralChecks = *spectralChecks - 1;
                return 0;
            }
            spectral_pack(cards, _pack.size, inst, ante);
        }
        else if (_pack.type == Arcana_Pack)
        {
            if (*arcanaChecks > 0)
            {
                *arcanaChecks = *arcanaChecks - 1;
                return 0;
            }
            arcana_pack(cards, _pack.size, inst, ante);
        }
        for (int index = 0; index < _pack.size; index++)
        {
            if (cards[index] == The_Soul)
            {
                jokerdata jkr = next_joker_with_info(inst, S_Soul, ante);
                if (jkr.joker == Perkeo)
                {
                    *perkeo = *perkeo + 1;
                }
                else if (jkr.joker == Canio)
                {
                    *canio = *canio + 1;
                }
                if (jkr.edition == Negative)
                {
                    return 1;
                }
            }
        }
        return 0;
    }
    return 0;
}

int check_next_shopitem(instance *inst, int ante)
{
    shopitem sItem = next_shop_item(inst, ante);
    return scoreCard(sItem.joker);
}

long filter(instance *inst)
{
    int souls = 0;
    int canio = 0;
    int yorick = 0;
    int perkeo = 0;
    int triboulet = 0;
    int chicot = 0;
    long score = 0;
    bool observatory = false;
    set_deck(inst, Ghost_Deck);
    set_stake(inst, Black_Stake);
    init_locks(inst, 1, false, false);

    for (int ante = 1; ante < 8; ante++)
    {
        if (next_voucher(inst, ante) == Telescope)
        {
            activate_voucher(inst, Telescope);
            if (next_voucher(inst, ante + 1) == Observatory)
            {
                observatory = true;
            }
        }
    }
    if (!observatory)
    {
        return 0;
    }

    for (int ante = 1; ante <= 8; ante++)
    {
        item tag = next_tag(inst, ante);
        item tag2 = next_tag(inst, ante);
        int spectralChecks = 0;
        int arcanaChecks = 0;
        if (tag == Charm_Tag)
            arcanaChecks += 1;
        if (tag == Ethereal_Tag)
            spectralChecks += 1;
        if (tag2 == Charm_Tag)
            arcanaChecks += 1;
        if (tag2 == Ethereal_Tag)
            spectralChecks += 1;

        for (int i = 0; i < arcanaChecks; i++)
        {
            item arcanaPack[5];
            arcana_pack(arcanaPack, 5, inst, ante);

            for (int j = 0; j < 5; j++)
            {
                if (arcanaPack[j] == The_Soul)
                {
                    souls += 1;
                    jokerdata jkr = next_joker_with_info(inst, S_Soul, ante);
                    if (jkr.joker == Perkeo)
                    {
                        perkeo += 1;
                    }
                    if (jkr.joker == Canio)
                    {
                        canio += 1;
                    }
                    if (jkr.joker == Triboulet)
                    {
                        triboulet += 1;
                    }
                    if (jkr.edition == Negative)
                    {
                        score += 1;
                    }
                }
            }
        }

        for (int i = 0; i < spectralChecks; i++)
        {
            item spectralPack[5];
            spectral_pack(spectralPack, 5, inst, ante);

            for (int j = 0; j < 5; j++)
            {
                if (spectralPack[j] == The_Soul)
                {
                    jokerdata jkr = next_joker_with_info(inst, S_Soul, ante);
                    if (jkr.joker == Perkeo)
                    {
                        perkeo += 1;
                    }
                    if (jkr.joker == Canio)
                    {
                        canio += 1;
                    }
                    if (jkr.joker == Triboulet)
                    {
                        triboulet += 1;
                    }
                    if (jkr.edition == Negative)
                    {
                        score += 1;
                    }
                }
            }
        }
        for (int packCheck = 0; packCheck < 4; packCheck++)
        {
            score += check_next_shopitem(inst, ante);
            score += check_next_pack(inst, ante, &arcanaChecks, &spectralChecks, &perkeo, &canio);
            for (int anteExtra = 0; anteExtra < ante; anteExtra++)
            {
                score += check_next_shopitem(inst, ante);
            }
        }
    }

    if (perkeo == 0 && canio == 0)
    {
        return 0;
    }

    return score;
}