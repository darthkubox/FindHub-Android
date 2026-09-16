#!/usr/bin/env python3
"""Read-only comparison with the source snapshot; never restores or writes source files."""
import hashlib
import json
from pathlib import Path
import sys

release_root = Path(__file__).resolve().parents[1]
source_root = release_root.parent
snapshot = json.loads((release_root / 'docs/evidence/source-snapshot.json').read_text())['sha256']
changed = []
for relative, expected in snapshot.items():
    path = source_root / relative
    if not path.is_file():
        changed.append(f'MISSING: {relative}')
    elif hashlib.sha256(path.read_bytes()).hexdigest() != expected:
        changed.append(f'CHANGED: {relative}')
# Newly created source files also count as a source-tree change.
current = {str(p.relative_to(source_root)) for p in (source_root / 'MotoHub').rglob('*') if p.is_file()}
changed.extend(f'ADDED: {name}' for name in sorted(current - set(snapshot)))
if changed:
    print('\n'.join(changed))
    print('Source differs from the copy-time snapshot. No files were modified by this check.')
    sys.exit(1)
print(f'PASS: {len(snapshot)} original files unchanged; no files added to original MotoHub.')
