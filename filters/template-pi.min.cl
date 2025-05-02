#include "lib/immolate.cl"
#define _DF 100000000
#define _D1 10000000
#define _D2 1000000
#define _D3 100000
#define _D4 10000
#define _D5 1000
#define _D6 100
#define _D7 10
#define _DL 1

long filter(instance *i) {
  set_deck(i, Anaglyph_Deck);
  set_stake(i, White_Stake);
  init_locks(i, 1, false, true);

  #define N 3
  #define W 6
  #define NBA 3
  #define WBA 8
  #define NBAP 6
  item n[N] = { Wee_Joker, Hack, Showman };
  bool sn[N] = { false, false, false };
  item w[W] = { Blueprint, Brainstorm, Oops_All_6s, Lucky_Cat, Hack, The_Soul };
  int sw[W] = { 0, 0, 0, 0, 0, 0 };

  int sd[7] = {_D1, _D2, _D3, _D4, _D5, _D6, _D7};
  int oa = 99;
  int ta = 99;
  int nt = 0;
  bool p = false;
  int nj = 0;
  item c[128];
  for (int i = 0; i < 128; i++) c[i] = RETRY;
  int sc = 0;
  bool m = false;

  int ats = WBA;
  for (int a = 1; a <= ats; a++) {
    init_unlocks(i, a, false);
    item cv = next_voucher(i, a);
    if (ta == 99 && cv == Telescope) {
      ta = a;
      activate_voucher(i, Telescope);
    } else if (ta != 99 && oa == 99 && cv == Observatory) {
      oa = a;
    }
    if (next_tag(i, a) == Negative_Tag) nt++;
    next_orbital_tag(i);
    if (next_tag(i, a) == Negative_Tag) nt++;
    next_orbital_tag(i);
    next_orbital_tag(i);
    int ci = 0;
    sc = a == 1 ? 4 : 6 + a;

    for (int s = 0; s < sc; s++) {
      shopitem si = next_shop_item(i, a);
      if (si.value == RETRY) continue;
      if (si.type == ItemType_Joker) {
        if (si.joker.edition == Negative) nj++;
      }
      c[ci++] = si.value;
    }

    int pc = a == 1 ? 4 : 6;
    for (int p = 0; p < pc; p++) {
      item ct[5] = {RETRY, RETRY, RETRY, RETRY, RETRY};
      pack pk = pack_info(next_pack(i, a));
      if (pk.type == Arcana_Pack) 
        arcana_pack(ct, pk.size, i, a);
      else if (pk.type == Spectral_Pack)
        spectral_pack(ct, pk.size, i, a);
      else if (pk.type == Buffoon_Pack)
        buffoon_pack(ct, pk.size, i, a);
      else continue;
      for (int t = 0; t < pk.size; t++) {
        c[ci++] = ct[t];
      }
    }

    for (int cq = 0; cq < 126; cq++) {
      item j = cq[c];
      if (j == RETRY) continue;
      if (j == Showman) i->params.showman = true;
      if (j == The_Magician) m = true;
      if (j == Lucky_Cat && !m) continue;
      if (j == The_Soul) {
        jokerdata jd = next_joker_with_info(i, S_Soul, a);
        j = jd.joker;
        for (int ww = 0; ww < W; ww++) {
          if (The_Soul == w[ww]) sw[ww]++;
        }
      }
      if (j == Perkeo) p = true;
      for (int x = 0; x < N; x++) {
        if (j == n[x] && (sn[x] == 0 || i->params.showman == true)) {
          sn[x] = true;
          break;
        }
      }
      for (int x = 0; x < W; x++) {
        if (j == w[x] && (sw[x] == 0 || i->params.showman == true)) {
          sw[x]++;
          break;
        }
      }
    }
    if (a == NBA) {
      for (int n = 0; n < N; n++) {
        if (sn[n] == false) return 0;
      }
    }
    if (a == NBAP) {
      if (p == false) return 0;
    }
  }
  if (oa == 99) return 0;

  long s = 0;
  long swt = 0;
  for (int w = 0; w < W; w++) {
    if (sw[w] > 0) swt++;
    s += sw[w] * sd[w];
  }
  s += swt * _DF;
  s += nt > 10 ? 9*_D7 : nt*_D7;
  s += nj * _DL;

  return s;
}