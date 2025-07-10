#!/usr/bin/env python3
import glob
import pandas as pd
from rdkit import Chem

rows = []
skipped = []

for fn in glob.glob("scored/*_scored.sdf"):
    base = fn.split("/")[-1].replace("_scored.sdf","")
    try:
        suppl = Chem.SDMolSupplier(fn, sanitize=False, removeHs=False)
    except Exception as e:
        skipped.append((base, str(e)))
        continue

    mols = [m for m in suppl if m is not None]
    if not mols:
        skipped.append((base, "no molecules parsed"))
        continue

    for mol in mols:
        data = {"ligand": base}
        for tag in ("CNNscore","CNNaffinity","Affinity"):
            data[tag] = float(mol.GetProp(tag)) if mol.HasProp(tag) else None
        rows.append(data)

# Report skipped files
if skipped:
    print(f"⚠️  Skipped {len(skipped)} files due to parse errors:")
    for name, err in skipped:
        print(f"  - {name}: {err}")

# Build and write the CSV
df = pd.DataFrame(rows)
df = df.sort_values("CNNaffinity", ascending=False).reset_index(drop=True)
df.to_csv("gnina_scores.csv", index=False)
print(f"✅  Wrote {len(df)} scored ligands to gnina_scores.csv")
