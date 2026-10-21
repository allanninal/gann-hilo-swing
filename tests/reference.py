# SPDX-License-Identifier: LicenseRef-PolyForm-Noncommercial-1.0.0 (see LICENSE)
"""Python twin of Gann.mqh (HiLo activator, 2-bar swing chart, pivots, new trends), operation for operation, for the
parity check (tests/check_parity.py).

    from reference import run
    rows, pivots = run(high, low, close, hilo=3, swing_confirm=True)
"""


def run(h, l, c, hilo=3, swing_confirm=True):
    """Per bar: line, trend, side, ev (+1/-1 new trend); pivots: list of (confirm_bar, pivot_bar, price, type)."""
    n = len(c)
    rows, pivots = [], []
    hi_prev = lo_prev = None
    trend = sd = side = 0
    cur_min = cur_max = 0.0
    cur_min_bar = cur_max_bar = 0
    for k in range(n):
        ev = 0
        t = trend
        if hi_prev is not None:
            eps = 1e-9 * abs(c[k])
            if c[k] - hi_prev > eps:
                t = 1
            elif lo_prev - c[k] > eps:
                t = -1
        trend = t
        hi = lo = None
        if k >= hilo - 1:
            sh = sl = 0.0
            for j in range(k - hilo + 1, k + 1):
                sh += h[j]
                sl += l[j]
            hi, lo = sh / hilo, sl / hilo
        line = lo if t > 0 else (hi if t < 0 else None)
        hi_prev, lo_prev = hi, lo
        if k == 0:
            cur_min, cur_max, cur_min_bar, cur_max_bar = l[0], h[0], 0, 0
        if k >= 2:
            up = h[k] > h[k - 1] and h[k - 1] > h[k - 2]
            dn = l[k] < l[k - 1] and l[k - 1] < l[k - 2]
            nw = sd
            if up and dn:
                nw = 1 if c[k] > c[k - 1] else -1
            elif up:
                nw = 1
            elif dn:
                nw = -1
            if nw != sd:
                if nw == 1:
                    m, mb = cur_min, cur_min_bar
                    if l[k] < m:
                        m, mb = l[k], k
                    if sd != 0:
                        pivots.append((k, mb, m, -1))
                    cur_max, cur_max_bar = h[k], k
                else:
                    m, mb = cur_max, cur_max_bar
                    if h[k] > m:
                        m, mb = h[k], k
                    if sd != 0:
                        pivots.append((k, mb, m, 1))
                    cur_min, cur_min_bar = l[k], k
                sd = nw
            else:
                if l[k] < cur_min:
                    cur_min, cur_min_bar = l[k], k
                if h[k] > cur_max:
                    cur_max, cur_max_bar = h[k], k
        prev = side
        if not swing_confirm:
            side = t
        elif t == 1 and sd == 1:
            side = 1
        elif t == -1 and sd == -1:
            side = -1
        if side != prev and side != 0 and k >= hilo + 2 and prev != 0:
            ev = side
        rows.append(dict(line=line, trend=t, side=side, sd=sd, ev=ev))
    return rows, pivots
