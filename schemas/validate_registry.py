#!/usr/bin/env python3
"""Valide chaque fiche de registry/<environment>/*.yml contre
schemas/registry-entry.schema.json (04E § 6.13, 06B v0.2 T1.2.1bis, F9.1).

Usage : schemas/validate_registry.py [registry_dir ...]
Sans argument, valide registry/staging/ et registry/production/.
Code de sortie non nul si une fiche est invalide (destiné à la CI).
"""
import json
import sys
from pathlib import Path

import yaml
from jsonschema import Draft202012Validator

REPO_ROOT = Path(__file__).resolve().parent.parent
SCHEMA_PATH = REPO_ROOT / "schemas" / "registry-entry.schema.json"


def main() -> int:
    schema = json.loads(SCHEMA_PATH.read_text())
    validator = Draft202012Validator(schema)

    dirs = [Path(a) for a in sys.argv[1:]] or [
        REPO_ROOT / "registry" / "staging",
        REPO_ROOT / "registry" / "production",
    ]

    failures = 0
    checked = 0
    for d in dirs:
        for f in sorted(d.glob("*.yml")):
            checked += 1
            label = f.relative_to(REPO_ROOT) if REPO_ROOT in f.parents else f
            data = yaml.safe_load(f.read_text())
            errors = sorted(validator.iter_errors(data), key=lambda e: list(e.path))
            if errors:
                failures += len(errors)
                print(f"ECHEC  {label}")
                for e in errors:
                    print(f"    {list(e.path)}: {e.message}")
            else:
                print(f"OK     {label}")

    print(f"\n{checked} fiche(s) vérifiée(s), {failures} erreur(s).")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
