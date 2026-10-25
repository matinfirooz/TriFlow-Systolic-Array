#!/usr/bin/env python3
"""Delete only generated build output in this repository."""
from pathlib import Path
import shutil
root=Path(__file__).resolve().parents[1]
for name in ['build','dist']:
    path=root/name
    if path.is_dir() and not path.is_symlink():shutil.rmtree(path)
for parent in ['scripts','sw','tests']:
    for path in (root/parent).rglob('__pycache__'):
        if path.is_dir() and not path.is_symlink():shutil.rmtree(path)
print('Removed scoped build output; source, assets and reports are preserved.')
