# SPDX-License-Identifier: LicenseRef-PolyForm-Noncommercial-1.0.0 (see LICENSE)
"""Compare what the indicator drew (DumpIndicator CSVs on MT5, Dump4 CSVs on MT4) with tests/reference.py, bar by bar.

    python3 tests/check_parity.py <dump dir>          (needs numpy and pandas; looks in <dump dir>/dump)
    python3 tests/check_parity.py <dump dir> --mt4    (the MT4 edition, dumps from the MT4 tester)

Buffers: b0 new-uptrend arrow, b1 new-downtrend arrow, b2 HiLo line, b3 its colour (0 up, 1 down), b4 swing line
(price on each confirmed pivot bar), b5 side, b6 activator trend. The indicator scans InpHistory closed bars.
Pass: line within 1e-9 relative, trend, side, arrows and swing pivots identical on every scanned bar."""
import sys
from pathlib import Path

import numpy as np
import pandas as pd

sys.path.insert(0, str(Path(__file__).parent))
from reference import run  # noqa: E402

CONFIGS = {"gn_default": (3, True, 3000), "gn_hilo5_noswing": (5, False, 3000)}
# DumpIndicator InpParams for MT5 in input order (each input group counts as a string parameter); as tests/configs.tsv
MT5_PARAMS = {"gn_default": "s:Gann HiLo and swing|i:3|b:true|b:true|s:Display|i:3000|c:16748574|c:4678655|s:Alerts|b:false|b:false|s:alert.wav|b:false|b:false",
              "gn_hilo5_noswing": "s:Gann HiLo and swing|i:5|b:false|b:true|s:Display|i:3000|c:16748574|c:4678655|s:Alerts|b:false|b:false|s:alert.wav|b:false|b:false"}


def num(col):
    return pd.to_numeric(col, errors="coerce").to_numpy(float)


def check(csv, hilo, swing, hist, mt4=False):
    d = pd.read_csv(csv)
    n = len(d)
    # MT4 tester: the indicator was attached with far fewer than InpHistory bars, so it starts at bar 0 and keeps
    # feeding (arrows are compared by bar only, as before: MT4 puts them a multiple of ATR from the candle)
    start = 0 if mt4 else max(0, n - 1 - hist)
    h, l, c = (d[k].to_numpy(float)[start:n - 1] for k in ("high", "low", "close"))
    rows, piv = run(h, l, c, hilo, swing)
    m = len(rows)
    ref_line = np.array([np.nan if r["line"] is None else r["line"] for r in rows])
    ok_line = np.isclose(num(d["b2"])[start:start + m], ref_line, rtol=1e-9, atol=0, equal_nan=True)
    ok_side = num(d["b5"])[start:start + m] == np.array([r["side"] for r in rows])
    ok_trend = num(d["b6"])[start:start + m] == np.array([r["trend"] for r in rows])
    up = sorted(i for i in np.flatnonzero(~np.isnan(num(d["b0"])[start:start + m])))
    dn = sorted(i for i in np.flatnonzero(~np.isnan(num(d["b1"])[start:start + m])))
    rup = [k for k, r in enumerate(rows) if r["ev"] > 0]
    rdn = [k for k, r in enumerate(rows) if r["ev"] < 0]
    sw = num(d["b4"])[start:start + m]
    mt_piv = {int(i): sw[i] for i in np.flatnonzero(~np.isnan(sw))}
    ref_piv = {pb: px for _, pb, px, _ in piv}
    ok_piv = mt_piv.keys() == ref_piv.keys() and all(abs(mt_piv[k] - ref_piv[k]) <= 1e-9 * abs(ref_piv[k]) for k in ref_piv)
    ok = ok_line.all() and ok_side.all() and ok_trend.all() and up == rup and dn == rdn and ok_piv
    msg = (f"{csv.stem:34} bars {m:>5}  line {'OK' if ok_line.all() else (~ok_line).sum()}  side {'OK' if ok_side.all() else (~ok_side).sum()}"
           f"  trend {'OK' if ok_trend.all() else (~ok_trend).sum()}  up {len(rup):>3} {'OK' if up == rup else 'DIFFER'}"
           f"  down {len(rdn):>3} {'OK' if dn == rdn else 'DIFFER'}  pivots {len(ref_piv):>4} {'OK' if ok_piv else 'DIFFER'}")
    return ok, msg


if __name__ == "__main__":
    mt4 = "--mt4" in sys.argv          # dumps of the MT4 Strategy Tester run
    root = Path([a for a in sys.argv[1:] if a != "--mt4"][0])
    allok, k = True, 0
    for tag, (hilo, swing, hist) in CONFIGS.items():
        for f in sorted(root.glob(f"dump/{tag}_*.csv")):
            ok, msg = check(f, hilo, swing, hist, mt4)
            allok &= ok
            k += 1
            print(("PASS " if ok else "FAIL ") + msg)
    print(f"\n{'ALL PASS' if allok and k else 'FAILURES'} ({k} files)")
    sys.exit(0 if allok and k else 1)
