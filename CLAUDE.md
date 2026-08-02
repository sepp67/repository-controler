# CLAUDE.md — Repository Controller `reverse_proxy`

## Contexte du projet

Ce dépôt implémente un rôle Ansible unique, `reverse_proxy`, gérant deux
reverse proxies Caddy (staging, production) pour l'infrastructure Lavallee.
Il ne déploie **aucune** application — sa seule responsabilité est le routage
HTTP/HTTPS déclaré dans `registry/`.

## Documents de référence — autorité absolue

- `docs/04E-proposition-architecture-reverse-proxy-claude-v0_3.md` — architecture technique. Seule source de vérité pour toute décision de conception. Ne jamais dévier sans validation humaine explicite.
- `docs/06B-plan-developpement-deepseek-v0_2.md` — plan de développement. Fournit l'ordre des Epics/Features/Tasks, les critères d'acceptation, et la matrice de dépendances à respecter.
- `docs/MIGRATION-NOTES.md` — faits vérifiés sur le dépôt source réel (`devops_staging_prod_infra`) et données d'infrastructure confirmées lors de l'analyse de migration.

Ces trois documents sont le produit d'un travail d'arbitrage humain approfondi
(neuf arbitrages, dix-huit clarifications). Ils ne sont pas des brouillons —
toute proposition de les modifier doit être signalée explicitement à
l'opérateur, jamais appliquée silencieusement.

## Règles absolues (non négociables)

1. **Aucun playbook ni tâche du rôle n'écrit jamais dans `registry/`** — ni ajout, ni modification, ni suppression, dans aucun mode d'exécution. Seul l'opérateur humain modifie le registre (édition manuelle, commit, push). C'est la règle la plus structurante de 04E (§ 9.4, ARCH-CAND-010/014) : ne jamais la contourner, même pour une commodité apparente (auto-complétion, génération de squelette de fiche, etc.).
2. **Deux playbooks publics seulement** : `converge-proxy.yml` (convergence complète transactionnelle) et `converge-route.yml` (convergence ciblée, comportement PRESENT/ABSENT/no-op/incohérence). N'en créer aucun autre.
3. **Aucun index ou fichier d'état persistant** sur la VM proxy en dehors des fragments Caddy eux-mêmes — principe de non-persistance des états dérivables (04E § 12, ARCH-CAND-022). L'identité d'un fragment repose exclusivement sur son nom de fichier et son en-tête auto-descriptif.
4. **Un fragment Caddy par service publié**, jamais par route individuelle : `<project_name>__<service_id>.caddy`. Un fragment par route produit des adresses de site Caddy dupliquées et échoue à `caddy validate` (04E § 8.3, § 15).
5. Le transport Caddy → backend reste **implicitement et exclusivement `http`** en V1. N'ajouter aucun champ `protocol` dans `backends[]`, même à titre d'option non utilisée.
6. `project_name`, `service_id`, `route_id`, `backend_id` : format `[a-z0-9-]+` strict. **Le caractère `_` y est interdit** (condition nécessaire au nommage sans ambiguïté des fragments, 04E § 6.11/§ 8.3).
7. Systèmes cibles : **Debian et Ubuntu exclusivement**. Toute tâche d'installation doit vérifier l'OS et échouer explicitement sinon (04E § 3.1, ARCH-CAND-027).
8. Toute convergence, ciblée ou complète, doit d'abord vérifier la propreté Git de l'intégralité de `registry/<environment>/` (préflight, 04E § 9.5) — jamais seulement le fichier concerné.
9. **Ne jamais exécuter un playbook contre `inventories/production/`** sans validation humaine explicite, préalable et séparée de toute session de développement.

## Discipline de travail

- Ne prends jamais de décision silencieuse sur un point non tranché par 04E ou 06B v0.2. En cas d'ambiguïté ou de contradiction, arrête-toi et pose la question plutôt que de choisir à la place de l'opérateur — c'est la méthode qui a produit ces deux documents, elle s'applique aussi à leur implémentation.
- N'invente jamais de valeur d'infrastructure (IP, domaine, port, identifiant). Si une valeur nécessaire n'apparaît ni dans `docs/MIGRATION-NOTES.md`, ni dans `inventories/`, ni dans `registry/`, demande-la explicitement.
- Suis l'ordre des Epics de 06B v0.2 (§ 9-10) : ne commence pas une Task dont une dépendance déclarée n'est pas satisfaite.
- Chaque Task de 06B v0.2 porte des critères d'acceptation explicites (colonne « Critères d'acceptation ») — vérifie-les avant de considérer une Task terminée, et signale tout écart plutôt que de le corriger silencieusement dans la spécification.
- Si l'implémentation d'une Task révèle une incohérence ou un cas non prévu par 04E/06B (comme cela s'est produit plusieurs fois durant leur rédaction — voir par exemple la révision du modèle de fragment en 04E § 15), documente-le clairement et propose une résolution à valider, sans trancher seul un point structurant.

## État actuel du dépôt

- `inventories/` — peuplé (staging + production), valeurs réelles confirmées par l'opérateur.
- `registry/staging/` — **9 fiches réelles**, migrées depuis le dépôt source `devops_staging_prod_infra` et validées (unicité, cohérence `handler`/`backends`/`redirect`).
- `registry/production/` — **3 fiches réelles** (`matrix-users`, `matrix-bridges`, `element-web`). Les 5 fiches restantes (`lavallee-website`, `facturier`, `nextcloud`, `keycloak`, `webcam`) sont **volontairement absentes** : leurs backends de production sont encore des placeholders `TODO` dans le dépôt source réel lui-même — voir `docs/MIGRATION-NOTES.md`. Ne jamais créer ces fiches avec des valeurs inventées ; demander confirmation des IP réelles à l'opérateur.
- `playbooks/`, `roles/reverse_proxy/*`, `schemas/`, `tests/` — structure vide, à implémenter. Chaque répertoire contient un `README.md` précisant ce qui y est attendu et la Task 06B v0.2 correspondante.

## Prochaine étape suggérée

Commencer par **EPIC-01** (06B v0.2 § 9-10) :
1. `schemas/registry-entry.schema.json` (Task T1.2.1bis), validé contre les 12 fiches déjà présentes dans `registry/`.
2. `roles/reverse_proxy/tasks/registry_load.yml` (Task T1.2.2bis).
3. `roles/reverse_proxy/tasks/preflight.yml` (Task T1.3.1).

Puis suivre l'ordre EPIC-02 → EPIC-09 tel que défini en 06B v0.2 § 6/§ 13/§ 14
(stratégie de séquencement, dépendances, chemin critique).
