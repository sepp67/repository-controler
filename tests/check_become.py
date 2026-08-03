#!/usr/bin/env python3
"""Vérifie statiquement que toute tâche écrivant sur le système de fichiers
de la VM proxy porte `become: true` (directement, ou via un bloc englobant
qui le porte) — sans quoi elle échoue en pratique dès que l'utilisateur SSH
n'est pas root (constaté deux fois en usage réel : install.yml puis
fragment_render.yml, aucune des deux fois détecté par la suite de tests, qui
retire `become: true` de sa copie de travail pour s'exécuter sans droits
root, cf. tests/run_tests.sh — ce script comble ce trou par une analyse
statique, sans dépendre de droits root ni de Docker).

N'inspecte pas les tâches déléguées au contrôleur (`delegate_to: localhost`)
— ces tâches agissent sur le registre Git/le contrôleur, jamais sur la VM
proxy, et n'ont donc pas besoin de `become`.

Usage : tests/check_become.py
Code de sortie non nul si une tâche est suspecte.
"""
import sys
from pathlib import Path

import yaml

REPO_ROOT = Path(__file__).resolve().parent.parent
TASKS_DIR = REPO_ROOT / "roles" / "reverse_proxy" / "tasks"

# Modules dont l'exécution modifie effectivement l'état de la VM cible.
WRITE_MODULES = {
    "ansible.builtin.template",
    "ansible.builtin.copy",
    "ansible.builtin.file",
    "ansible.builtin.command",
    "ansible.builtin.shell",
    "ansible.builtin.systemd",
    "ansible.builtin.apt",
    "ansible.builtin.apt_repository",
    "ansible.builtin.apt_key",
    "ansible.builtin.get_url",
    "ansible.builtin.lineinfile",
}
# Modules en lecture seule : jamais concernés, même sans become (traversée/
# lecture suffisantes avec les permissions 0755/0644 déjà en usage ici).
READ_ONLY_MODULES = {
    "ansible.builtin.stat",
    "ansible.builtin.slurp",
    "ansible.builtin.find",
    "ansible.builtin.assert",
    "ansible.builtin.set_fact",
    "ansible.builtin.debug",
    "ansible.builtin.fail",
    "ansible.builtin.include_tasks",
    "ansible.builtin.import_tasks",
}


def walk(tasks, inherited_become, inherited_delegate, findings, path):
    for task in tasks:
        if not isinstance(task, dict):
            continue
        become = task.get("become", inherited_become)
        delegate = task.get("delegate_to", inherited_delegate)
        name = task.get("name", "(sans nom)")

        for block_key in ("block", "rescue", "always"):
            if block_key in task:
                walk(task[block_key], become, delegate, findings, path)

        module_keys = [
            k
            for k in task
            if k in WRITE_MODULES or k in READ_ONLY_MODULES
        ]
        for mod in module_keys:
            if mod in WRITE_MODULES and delegate != "localhost" and not become:
                findings.append(f"{path.name} :: {name}  [{mod}, become manquant]")


def main() -> int:
    findings = []
    for f in sorted(TASKS_DIR.glob("*.yml")):
        data = yaml.safe_load(f.read_text())
        if not isinstance(data, list):
            continue
        walk(data, False, None, findings, f)

    if findings:
        print("Tâches suspectes (écriture sur la VM cible sans become: true) :")
        for line in findings:
            print(f"  - {line}")
        return 1

    print("Aucune tâche d'écriture sans become: true détectée.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
