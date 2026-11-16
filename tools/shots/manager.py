"""Nano Manager shots come from the app's golden images (real renders, fixture data).

Usage: python3 tools/shots/manager.py   (nano-pos-manager must sit next to this repo)
"""
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).parent))
from to_webp import convert  # noqa: E402

ROOT = pathlib.Path(__file__).resolve().parents[2]
GOLDENS = ROOT.parent / 'nano-pos-manager' / 'test' / 'goldens'
SHOTS = {
    'manager-home': 'home_light.png',
    'manager-stocktake': 'stocktake_count_light.png',
    'manager-debt': 'customer_debt_light.png',
    'manager-receipt': 'receipt_editor_light.png',
}

if __name__ == '__main__':
    out = ROOT / 'assets' / 'shots'
    out.mkdir(parents=True, exist_ok=True)
    for name, golden in SHOTS.items():
        convert(str(GOLDENS / golden), str(out / f'{name}.webp'), width=720)
        print(name)
