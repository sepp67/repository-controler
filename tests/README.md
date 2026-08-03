# tests/

Voir 04E § 20 (matrice de tests complète) et 06B v0.2 EPIC-09 (Features F9.1,
F9.2).

## `run_tests.sh`

Suite de tests fonctionnels consolidée (T9.2.1), couvrant tous les scénarios
de 04E § 20 : préflight Git, les cinq cas de `converge-route.yml` (PRESENT,
ABSENT-service-présent, ABSENT-service-disparu, no-op, incohérence) + la
sélection ambiguë, les deux cas de `converge-proxy.yml` (succès, échec
transactionnel intégral) + le nettoyage des orphelins, l'idempotence des deux
playbooks, le cas Matrix à deux services (04E § 6.12.6, F12.1) et l'endpoint
`root.crt` démarré réellement — pas seulement validé (04E § 10.2, F12.1) —
et le journal de déploiement append-only (T9.2.2).

```bash
bash tests/run_tests.sh
```

Ne touche jamais `registry/` (le vrai registre du dépôt) ni un vrai système :
tout s'exécute dans un espace de travail jetable (`mktemp -d`), avec un
inventaire et un registre de test isolés, un binaire `caddy` réel extrait
sans droits root (via `docker`), et `install.yml` stubbé (l'installation
réelle de paquets/service systemd n'est pas testable sans VM Debian/Ubuntu
dédiée ni droits root — couverte séparément, cf. garde OS d'EPIC-02/EPIC-08).

Prérequis : `ansible-playbook`, `docker` (ou un binaire `caddy` déjà sur
`PATH`).

## Validation de forme et de schéma (F9.1)

Exécutée par `.github/workflows/ci.yml` :

- `yamllint -c .yamllint.yml registry/ inventories/` (T1.2.3)
- `python3 schemas/validate_registry.py` (validation JSON Schema, T1.2.1bis)
- `ansible-playbook --syntax-check` sur les deux playbooks publics
- `ansible-lint roles/ playbooks/`
