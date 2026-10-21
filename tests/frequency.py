# SPDX-License-Identifier: LicenseRef-PolyForm-Noncommercial-1.0.0 (see LICENSE)
"""Count new trends and swing pivots per 1,000 closed bars from the OHLC columns of dump CSVs (aggregate numbers only).

    python3 tests/frequency.py <dump dir> M15 H1 H4 > docs/data/trend-frequency.json
Reads <dump dir>/dump/gn_default_<SYMBOL>_<TF>.csv; every closed bar is scanned with tests/reference.py (defaults)."""
import json
import sys
from pathlib import Path

import pandas as pd

sys.path.insert(0, str(Path(__file__).parent))
from reference import run  # noqa: E402

root = Path(sys.argv[1])
result = {}
for tf in sys.argv[2:]:
    bars = trends = pivots = 0
    per_symbol = {}
    for f in sorted(root.glob(f"dump/gn_default_*_{tf}.csv")):
        d = pd.read_csv(f)
        h, l, c = (d[k].to_numpy(float)[:-1] for k in ("high", "low", "close"))
        rows, piv = run(h, l, c, 3, True)
        nt = sum(1 for r in rows if r["ev"])
        per_symbol[f.stem.split("_")[2]] = dict(bars=len(c), new_trends=nt, pivots=len(piv))
        bars += len(c); trends += nt; pivots += len(piv)
    result[tf] = dict(closed_bars=bars, per_symbol=per_symbol, new_trends_per_1000_bars=round(1000 * trends / bars, 2),
                      pivots_per_1000_bars=round(1000 * pivots / bars, 2), bars_per_new_trend=round(bars / max(1, trends), 1))
print(json.dumps(result, indent=1))
