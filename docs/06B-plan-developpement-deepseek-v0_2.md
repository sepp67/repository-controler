# Plan de développement

## Métadonnées

| Champ               | Valeur                                            |
| ------------------- | -------------------------------------------------- |
| IA                  | DeepSeek (rôle de planification exécuté par Claude, sur demande explicite de l'opérateur, conformément à `templates/06A-planification-implementation-architecture-deepseek.md`) |
| Version             | 0.2 — proposition candidate révisée |
| Date                | 2026-08-02 |
| Projet              | Rôle Ansible de gestion des reverse proxies Caddy |
| Architecture source | SRC-004bis (`04E-proposition-architecture-reverse-proxy-claude-v0.3.md`) |
| Document précédent  | `06B-plan-developpement-deepseek.md`, version 0.1 |
| Statut              | Proposition de planification candidate révisée — ne constitue ni une autorisation d'implémentation, ni une architecture, ni un ADR |

Ce document est autonome : il reprend intégralement le plan 0.1, révisé pour refléter 04E. Toute section non explicitement modifiée ci-dessous reste inchangée dans son principe depuis la version 0.1 et n'est reprise que par référence.

---

# 1. Documents d'entrée recensés

| ID source | Nom exact | Type | Informations utilisées | Utilisé |
| --------- | --------- | ---- | ---------------------- | ------- |
| SRC-001 à SRC-007 | Documents recensés en 06B v0.1 § 1 | — | Inchangés, toujours en vigueur | Oui |
| SRC-004bis | `04E-proposition-architecture-reverse-proxy-claude-v0.3.md` | Proposition d'architecture révisée de Claude, v0.3 — **référence architecturale principale, remplace SRC-004** | Modèle `published_services`/`routes`/`backends`, garde Git généralisée, playbooks fusionnés, principe de non-persistance des états dérivables, endpoint `root.crt`, décisions ARCH-CAND-001 à 027 | Oui |
| SRC-011 (nouveau) | Échange d'arbitrage humain du 2026-08-02 (ARB-001 à ARB-009, clarifications A à R) | Réponses humaines directes aux questions ouvertes de 04D | Source primaire de chaque décision reprise dans SRC-004bis ; consultée uniquement via SRC-004bis, qui en constitue la version formalisée | Indirectement — via SRC-004bis, conformément à la hiérarchie des sources (04D § 4, inchangée) |

## 1.1 Traitement de SRC-004 (04D)

SRC-004 (04D, v0.2) n'est plus la référence architecturale principale, mais reste une source valide pour toute section que SRC-004bis (04E) n'a pas explicitement révisée — 04E le précise lui-même (« Toute section non explicitement révisée [...] reste inchangée depuis 04D et n'est reprise que par référence »). Ce plan applique la même règle : une Task de 06B v0.1 dont la source unique est SRC-004 et qui ne touche à aucun élément révisé par 04E reste valable sans modification.

## 1.2 Documents manquants et non utilisés

Inchangé depuis 06B v0.1 § 1.1 et § 1.2.

---

# 2. Matrice des décisions contraignantes

Les décisions DEC-001 à DEC-005, DEC-015, DEC-016, DEC-019 de 06B v0.1 restent inchangées (elles ne sont touchées par aucun arbitrage). Les décisions suivantes sont nouvelles ou révisées.

| ID décision | Décision | Source exacte | Conséquence sur le plan |
| ----------- | -------- | -------------- | ------------------------ |
| DEC-006 | Registre séparé en `registry/staging/` et `registry/production/` | SRC-004bis § 6.2, ARCH-CAND-015 | Inchangé depuis v0.1 |
| DEC-007 | Chaque fiche déclare le FQDN complet dans `domain` | SRC-004bis § 6.10, ARCH-CAND-016 | Inchangé |
| DEC-008bis | Une fiche déclare un ou plusieurs `published_services`, chacun avec plusieurs `routes`, chaque route un ou plusieurs `backends` | SRC-004bis § 6.4, ARCH-CAND-001/017 | **Révise DEC-008** : le schéma passe de deux niveaux (route/upstream) à trois niveaux (service/route/backend) ; impacte EPIC-01 (schéma), EPIC-03 (template) |
| DEC-009 | Configuration Caddy modulaire sous `/etc/caddy/conf.d/` | SRC-004bis § 8.1 | Inchangé |
| DEC-009bis | Un fragment Caddy par service publié (`<project_name>__<service_id>.caddy`), jamais par route individuelle | SRC-004bis § 8.3, ARCH-CAND-004/007 (révisées) | **Nouveau** : impacte directement EPIC-03 (rendu de fragment) |
| DEC-010 | Toute modification est validée dans un espace candidat complet avant application | SRC-004bis § 8.5, ARCH-CAND-012 | Inchangé |
| DEC-011 | La convergence complète échoue intégralement si une seule fiche est invalide | SRC-004bis § 9.2, ARCH-CAND-013 | Inchangé |
| DEC-012bis | Aucun playbook n'écrit jamais dans le registre Git, dans aucun mode ; la garde Git devient une précondition exécutable (`git status --porcelain`) portant sur l'ensemble du registre de l'environnement, avant toute convergence | SRC-004bis § 9.4, § 9.5, ARCH-CAND-010/014/025 | **Révise DEC-012** (limitée à la suppression en v0.1) : devient un principe transverse, impacte tous les Épics de convergence |
| DEC-020 (nouveau) | Fusion des playbooks ciblés en un unique `converge-route.yml`, comportement PRESENT/ABSENT/no-op/ambigu | SRC-004bis § 9.3, ARCH-CAND-023 | Fusionne les anciens EPIC-05 et EPIC-06 en un seul Épic |
| DEC-021 (nouveau) | Renommage de `deploy-reverse-proxy.yml` en `converge-proxy.yml` | SRC-004bis § 5, ARCH-CAND-024 | Renommage de tous les artefacts de nommage correspondants dans le plan |
| DEC-022 (nouveau) | Handler de route explicite (`reverse_proxy` \| `redirect`), mutuellement exclusif avec `backends[]`/`redirect` | SRC-004bis § 6.9, ARCH-CAND-026 | Le champ `redirects` racine de v0.1 est retiré du schéma ; impacte EPIC-01, EPIC-03 |
| DEC-023 (nouveau) | Aucun index persistant des artefacts gérés sur la VM proxy ; identité portée par le nommage déterministe et l'en-tête auto-descriptif du fragment | SRC-004bis § 8.4, § 8.7, § 12, ARCH-CAND-022 | Retire toute Task qui aurait introduit un index ; impacte EPIC-03, EPIC-06 (nettoyage des orphelins) |
| DEC-024 (nouveau) | Le certificat `root.crt` est distribué via un endpoint HTTP interne dédié en staging, et non par `fetch`/`slurp` Ansible | SRC-004bis § 10.2, ARCH-CAND-018 (révisée) | **Révise** l'ancien DEC-014 : impacte EPIC-07 (ex-EPIC-08), ajoute une Task de configuration d'un endpoint Caddy interne |
| DEC-025 (nouveau) | La V1 supporte exclusivement Debian et Ubuntu ; SELinux hors périmètre | SRC-004bis § 3.1, ARCH-CAND-027 | Contrainte ajoutée aux Tasks d'installation (EPIC-02) et à la checklist de préparation production |
| DEC-026 (nouveau) | Un journal de déploiement append-only est conservé hors de la VM proxy à des fins d'audit humain, sans jamais participer aux décisions du rôle | SRC-004bis § 9.7 | Nouvelle Task documentaire/outillage, non bloquante, dans EPIC-09 (CI) |

L'ancien DEC-013 (persistance de la CA staging), DEC-017 (transport backend `http`), DEC-018 (absence de champ `websocket`) restent inchangés, confirmés par SRC-004bis § 10.1, § 6.7/10.5, § 6.8 respectivement.

---

# 3. Résumé exécutif

Ce plan reprend l'intégralité de la structure de 06B v0.1, révisée pour refléter le passage au modèle à trois niveaux (`published_services` → `routes` → `backends`), la garde Git généralisée à toute convergence, la fusion des playbooks ciblés, l'endpoint HTTP dédié pour `root.crt`, et le principe de non-persistance des états dérivables. Le nombre d'Épics passe de 13 à 12 par fusion des anciens EPIC-05 (ajout/modification) et EPIC-06 (suppression) en un unique EPIC-05 de convergence ciblée.

---

# 4. Philosophie de développement

Inchangé depuis 06B v0.1 § 4.

---

# 5. Composants à implémenter

Reprend 06B v0.1 § 5, avec les composants suivants ajoutés ou révisés :

* schéma de registre à trois niveaux (service/route/backend) au lieu de deux (route/upstream) ;
* tâche de préflight Git (`tasks/preflight.yml`), nouvelle, appelée par tous les points d'entrée ;
* tâche de rendu de fragment de service (`tasks/fragment_render.yml`), nouvelle, appelée par les deux modes de convergence ;
* point d'entrée ciblé unique (`tasks/converge_route.yml`), remplace `targeted_apply.yml`/`targeted_remove.yml` ;
* endpoint Caddy interne dédié servant `root.crt`, nouveau composant côté `install.yml`/configuration globale staging ;
* aucun composant d'index d'artefacts (retiré par rapport à toute anticipation antérieure).

---

# 6. Stratégie de séquencement

Inchangée dans son principe depuis 06B v0.1 § 6 : le séquencement suit toujours la dépendance technique (schéma → installation → rendu → candidat/validation → convergence ciblée → convergence complète → TLS → tests → migration → documentation → validation finale). La fusion EPIC-05/EPIC-06 ne change pas cet ordre, seulement le nombre d'Épics distincts à cette étape.

---

# 7. Découpage en phases

Reprend 06B v0.1 § 7, avec renumérotation PH-06 à PH-15 décalée d'une unité à partir de la fusion (PH-06/PH-07 anciens fusionnent en une seule phase de convergence ciblée). Le détail complet de la nouvelle numérotation figure en § 25 (matrice de traçabilité).

---

# 8. Releases

Inchangé dans son principe depuis 06B v0.1 § 8.

---

# 9. Epics

Cette section remplace intégralement 06B v0.1 § 9. Douze Épics au lieu de treize.

## EPIC-01 — Fondations du dépôt et contrat de données du registre à trois niveaux

Justification : le schéma `published_services`/`routes`/`backends` (DEC-008bis) et le handler explicite `reverse_proxy`/`redirect` (DEC-022) sont des préalables à toute autre Task. Source : SRC-004bis § 6, § 14.

## EPIC-02 — Rôle `reverse_proxy` : installation, configuration globale et préflight Git

Justification : ajoute la contrainte Debian/Ubuntu (DEC-025) et le nouveau composant de préflight Git (DEC-012bis), préalable à toute convergence. Source : SRC-004bis § 3.1, § 7.3, § 9.5.

## EPIC-03 — Génération de fragments par service publié

Justification : la granularité de fragment change de la route au service (DEC-009bis), avec en-tête auto-descriptif portant l'identité de toutes les routes contenues (DEC-023). Source : SRC-004bis § 8.3, § 8.4.

## EPIC-04 — Espace candidat et bascule atomique

Justification : mécanisme inchangé dans son principe depuis 06B v0.1 EPIC-04, adapté à la granularité de service. Source : SRC-004bis § 8.5.

## EPIC-05 — Convergence ciblée unifiée (`converge-route.yml`)

Justification : fusionne les anciens EPIC-05 (ajout/modification) et EPIC-06 (suppression) de 06B v0.1, conséquence directe de DEC-012bis/DEC-020 : un seul comportement PRESENT/ABSENT/no-op/ambigu remplace deux playbooks distincts. Source : SRC-004bis § 9.3, ARCH-CAND-023.

## EPIC-06 — Convergence complète transactionnelle (`converge-proxy.yml`)

Justification : reprend l'ancien EPIC-07, renommé conformément à DEC-021, avec nettoyage des orphelins désormais fondé exclusivement sur la lecture des en-têtes de fragment (DEC-023), sans index. Source : SRC-004bis § 9.2, § 8.7.

## EPIC-07 — Gestion TLS staging

Justification : reprend l'ancien EPIC-08, révisé pour l'endpoint HTTP dédié (DEC-024) remplaçant `fetch`/`slurp`. Source : SRC-004bis § 10.1, § 10.2.

## EPIC-08 — Gestion TLS production

Justification : reprend l'ancien EPIC-09, inchangé. Source : SRC-004bis § 10.3.

## EPIC-09 — Stratégie de tests et intégration continue

Justification : reprend l'ancien EPIC-10, étendu aux nouveaux cas PRESENT/ABSENT/no-op/ambigu/incohérence et au journal de déploiement (DEC-026). Source : SRC-004bis § 9.6, § 9.7, § 20.

## EPIC-10 — Migration du dépôt existant

Justification : reprend l'ancien EPIC-11, révisé pour le mapping à trois niveaux du registre. Source : SRC-004bis § 21.

## EPIC-11 — Documentation opérateur

Justification : reprend l'ancien EPIC-12, révisé pour documenter le playbook unique de convergence ciblée, l'endpoint `root.crt` et l'absence d'index. Source : SRC-004bis § 5, § 10.2, § 12.

## EPIC-12 — Validation finale staging et préparation de la production

Justification : reprend l'ancien EPIC-13, révisé pour inclure la vérification Debian/Ubuntu (DEC-025) dans la checklist de préparation production. Source : SRC-004bis § 3.1, Mission § 10 item 30.

---

# 10. Features et Tasks

Cette section remplace intégralement 06B v0.1 § 10/§ 11 pour les Features directement touchées par l'arbitrage. Les Features non listées ci-dessous (ex. F2.1 installation initiale hors contrainte OS, F4.1/F4.2 espace candidat, F9.1 ACME production, F12.1 README, F13.1/F13.2 validation) restent inchangées dans leur contenu depuis 06B v0.1, à l'exception de leur numérotation d'Épic (§ 25).

## Feature F1.1 — Structure minimale du dépôt cible

Inchangée depuis 06B v0.1 F1.1 (T1.1.1, T1.1.2), à l'exception de la liste des fichiers de `roles/reverse_proxy/tasks/` désormais attendue (voir F2.2 révisée).

## Feature F1.2 — Contrat de données du registre à trois niveaux

| Task | Action précise | Entrées | Sorties attendues | Dépend de | Critères d'acceptation | Sources |
| ---- | --------------- | ------- | -------------------- | ---------- | ------------------------ | ------- |
| T1.2.1bis | Écrire `schemas/registry-entry.schema.json` couvrant `project_name`, `domain`, `published_services` (≥1, avec `service_id`, `listen_port`, `frontend_protocol` obligatoires), `routes` (≥1 par service, avec `route_id`, `handler` ∈ {`reverse_proxy`,`redirect`}), `backends` (≥1, obligatoire et exclusif si `handler=reverse_proxy`), `redirect` (obligatoire et exclusif si `handler=redirect`), tous les invariants d'unicité de SRC-004bis § 6.11, format `[a-z0-9-]+` de tous les identifiants | SRC-004bis § 6.5, § 6.6, § 6.9, § 6.11 | `schemas/registry-entry.schema.json` validant les 6 exemples § 6.12 de SRC-004bis | T1.1.1 | Les 6 exemples de SRC-004bis § 6.12 (y compris Matrix à deux services) passent la validation ; une fiche mêlant `backends` et `redirect` sur une même route échoue ; une fiche avec un identifiant contenant `_` échoue | SRC-004bis § 6.11, § 6.12 |
| T1.2.2bis | Implémenter `tasks/registry_load.yml` : chargement d'une ou plusieurs fiches, validation `ansible.builtin.assert`, et **résolution `domain → project_name`** pour le mode ciblé (recherche dans toutes les fiches de l'environnement, échec si zéro ou plusieurs correspondances) | T1.2.1bis, SRC-004bis § 7.3, § 9.3 | `roles/reverse_proxy/tasks/registry_load.yml` | T1.2.1bis | Une fiche invalide échoue avant tout rendu ; la résolution d'un domaine inexistant ou dupliqué échoue explicitement (« sélection ambiguë ») | SRC-004bis § 9.3 |
| T1.2.3 | Mettre en place `yamllint` sur `registry/` et `inventories/` | Inchangé depuis v0.1 T1.2.3 | — | T1.2.2bis | Inchangé | SRC-004bis § 20 |

## Feature F1.3 — Vérification exécutable de la propreté Git (nouvelle)

| Task | Action précise | Entrées | Sorties attendues | Dépend de | Critères d'acceptation | Sources |
| ---- | --------------- | ------- | -------------------- | ---------- | ------------------------ | ------- |
| T1.3.1 | Écrire `tasks/preflight.yml` : exécution de `git status --porcelain=v1 --untracked-files=all -- registry/<environment>/` depuis le nœud de contrôle, échec bloquant sur toute sortie non vide, vérification qu'un commit `HEAD` identifiable existe, capture du SHA pour réutilisation ultérieure (en-tête de fragment, journal) | SRC-004bis § 9.5, ARCH-CAND-025 | `roles/reverse_proxy/tasks/preflight.yml` | T1.1.1 | Une modification non commitée dans `registry/<environment>/` fait échouer l'exécution avant toute autre tâche ; le SHA de `HEAD` est disponible en variable pour les tâches suivantes | SRC-004bis § 9.5 |
| T1.3.2 | Ajouter le cas de test « registre non propre » à la matrice de tests (référence croisée avec EPIC-09) | T1.3.1 | Entrée de test documentée | T1.3.1 | Le test échoue explicitement, sans lecture applicative du registre | SRC-004bis § 9.5 |

## Feature F2.2 — Répertoire `conf.d`, contrainte Debian/Ubuntu et séparation des points d'entrée

| Task | Action précise | Entrées | Sorties attendues | Dépend de | Critères d'acceptation | Sources |
| ---- | --------------- | ------- | -------------------- | ---------- | ------------------------ | ------- |
| T2.2.1bis | Créer les squelettes `preflight.yml` (F1.3), `install.yml`, `registry_load.yml` (F1.2), `fragment_render.yml`, `candidate_build.yml`, `candidate_validate.yml`, `candidate_apply.yml`, `converge_route.yml`, `main.yml`, documentant en commentaire leur contrat et leur appelant | SRC-004bis § 7.3 (tableau des sous-composants) | Squelette de tous les fichiers de `tasks/` du rôle | T2.1.1 | Chaque fichier existe et documente qui l'appelle ; aucune logique dupliquée entre `converge_route.yml` et `main.yml` | SRC-004bis § 7.3 |
| T2.2.2bis | Ajouter une vérification à l'exécution que le système cible est Debian ou Ubuntu (`ansible_facts['os_family']`/`ansible_distribution`), échec explicite sinon | DEC-025, SRC-004bis § 3.1 | Garde dans `install.yml` | T2.2.1bis | L'exécution sur un système non Debian/Ubuntu échoue avant toute installation | SRC-004bis § 3.1, ARCH-CAND-027 |
| T2.2.3 | Déclarer les variables de rôle par défaut (`caddy_conf_d_dir`, `caddy_candidate_dir`, `registry_path` dérivé, `staging_ca_endpoint_domain`) | SRC-004bis § 7.4 | `roles/reverse_proxy/defaults/main.yml` | T2.2.2bis | `registry_path` jamais fourni manuellement ; `staging_ca_endpoint_domain` défini pour staging uniquement | SRC-004bis § 7.4 |

## Feature F3.1 — Rendu de fragment par service publié, multi-route, multi-backend

| Task | Action précise | Entrées | Sorties attendues | Dépend de | Critères d'acceptation | Sources |
| ---- | --------------- | ------- | -------------------- | ---------- | ------------------------ | ------- |
| T3.1.1bis | Écrire `templates/fragment.caddy.j2` : un bloc de site `domain:listen_port { }` par service, un `handle`/`route` par entrée de `routes[]` dans l'ordre déclaré, `reverse_proxy` avec répartition de charge native si plusieurs backends | Schéma validé (F1.2), exemples SRC-004bis § 6.12.1, § 6.12.2, § 6.12.5 | Fragment rendu conforme aux exemples site simple / Keycloak / cluster | T2.2.3 | Le rendu pour `www-lavallee`, `keycloak` et `application-cluster` produit une syntaxe Caddyfile plausible, un seul bloc de site par service | SRC-004bis § 6.12, § 8.3 |
| T3.1.2 (nouveau) | Générer l'en-tête auto-descriptif du fragment (`managed-by`, `schema-version`, `project-name`, `domain`, `service-id`, `listen-port`, `frontend-protocol`, une ligne `route-id` par route contenue, `source-commit`, `generated-at`) | SRC-004bis § 8.4 | En-tête intégré au template | T3.1.1bis | L'en-tête liste exactement les `route_id` présents dans le rendu ; `source-commit` correspond au SHA capturé par le préflight (F1.3) | SRC-004bis § 8.4, ARCH-CAND-007 |
| T3.1.3 (nouveau) | Implémenter le nommage déterministe du fichier de fragment (`<project_name>__<service_id>.caddy`) sans troncature ni hachage, échec de validation si le format des identifiants source est invalide | SRC-004bis § 8.3, § 6.11 | Fonction de nommage dans `fragment_render.yml` | T3.1.2 | Deux services de projets différents ne produisent jamais de collision de nom ; toute violation de format échoue avant génération | SRC-004bis § 8.3 |

## Feature F3.2 — Handler `redirect` et routes de repli

| Task | Action précise | Entrées | Sorties attendues | Dépend de | Critères d'acceptation | Sources |
| ---- | --------------- | ------- | -------------------- | ---------- | ------------------------ | ------- |
| T3.2.1bis | Étendre `fragment.caddy.j2` pour produire une directive `redir` avec cible et code de statut lorsque `handler=redirect`, et un bloc `reverse_proxy` lorsque `handler=reverse_proxy` ; `strip_prefix` uniquement appliqué dans le second cas | SRC-004bis § 6.9, exemple Nextcloud § 6.12.3 | Fragment Nextcloud conforme (redirections WebDAV + route générique) | T3.1.1bis | Le rendu de `nextcloud.yml` place les deux redirections `/.well-known/...` avant la route `/` ; aucune route ne mélange `backends` et `redirect` | SRC-004bis § 6.9, § 6.4 |
| T3.2.2bis | Tester le rendu multi-route sur un même service (Facturier, § 6.12.4) | T3.2.1bis | Fragment `facturier__web.caddy` conforme | T3.2.1bis | Les trois routes apparaissent dans l'ordre déclaré, un seul bloc de site pour le service `web` | SRC-004bis § 6.12.4 |
| T3.2.3 (nouveau) | Tester le rendu Matrix à deux services (§ 6.12.6) | T3.1.3 | Deux fragments distincts (`matrix__matrix-client.caddy`, `matrix__matrix-federation.caddy`) | T3.1.3 | Chaque fragment porte un bloc de site sur son propre port, aucune adresse dupliquée | SRC-004bis § 6.12.6 |

## Feature F5.1 — Point d'entrée unique de convergence ciblée (fusionne F5.1 et F6.1 de v0.1)

| Task | Action précise | Entrées | Sorties attendues | Dépend de | Critères d'acceptation | Sources |
| ---- | --------------- | ------- | -------------------- | ---------- | ------------------------ | ------- |
| T5.1.1 | Écrire `playbooks/converge-route.yml` acceptant `environment`, `domain`, `service_id`, `route_id` en paramètres obligatoires | SRC-004bis § 9.3 | `playbooks/converge-route.yml` | T2.2.1bis | L'absence d'un des quatre paramètres fait échouer le playbook avant toute action | SRC-004bis § 9.3, DEC-020 |
| T5.1.2 | Implémenter `tasks/converge_route.yml` : préflight → résolution `domain` → détermination du cas (PRESENT / ABSENT-service-présent / ABSENT-service-absent / no-op / incohérence) → régénération complète du fragment du service concerné → candidat → validation → application | T1.2.2bis, T1.3.1, T3.1.3, F4.1, F4.2 | `roles/reverse_proxy/tasks/converge_route.yml` | T5.1.1 | Chacun des cinq cas produit le comportement observable décrit en SRC-004bis § 9.3 | SRC-004bis § 9.3, ARCH-CAND-023 |
| T5.1.3 | Écrire les cinq scénarios de test dédiés (PRESENT, ABSENT-service-présent, ABSENT-service-absent, no-op, incohérence) | T5.1.2 | Scénarios de test | T5.1.2 | Chaque scénario produit exactement le résultat attendu, y compris l'absence de bascule pour le no-op | SRC-004bis § 20 |
| T5.1.4 (nouveau) | Implémenter la détection d'incohérence : fragment au nom attendu mais sans en-tête `managed-by`, ou en-tête déclarant un couple `project-name`/`service-id` différent | T3.1.2, T5.1.2 | Garde dans `converge_route.yml` | T5.1.2 | L'opération échoue sans bascule dans les deux sous-cas | SRC-004bis § 9.3, § 8.4 |

## Feature F6.1 — Point d'entrée `main.yml` et `converge-proxy.yml` (renommage, fusionne l'ancien F7.1)

| Task | Action précise | Entrées | Sorties attendues | Dépend de | Critères d'acceptation | Sources |
| ---- | --------------- | ------- | -------------------- | ---------- | ------------------------ | ------- |
| T6.1.1 | Renommer `deploy-reverse-proxy.yml` en `playbooks/converge-proxy.yml` (aucun paramètre de sélection) | DEC-021 | `playbooks/converge-proxy.yml` | T2.2.1bis | Le playbook s'exécute sans paramètre de service | SRC-004bis § 5, ARCH-CAND-024 |
| T6.1.2 | Implémenter `tasks/main.yml` : préflight → install si absent → chargement de toutes les fiches (échec intégral si une seule invalide) → régénération d'un fragment par service publié attendu → exclusion des orphelins gérés (par lecture d'en-tête, sans index) → candidat → validation → application | T1.3.1, T3.1.3, F4.1, F4.2 | `roles/reverse_proxy/tasks/main.yml` | T6.1.1 | Une fiche invalide bloque l'intégralité de l'opération ; un fragment géré dont le service n'existe plus est exclu sans affecter les autres | SRC-004bis § 9.2, § 8.7, ARCH-CAND-013/022 |
| T6.1.3 | Tests de convergence complète réussie et en échec | T6.1.2 | Scénarios de test | T6.1.2 | Conforme à SRC-004bis § 9.2 | SRC-004bis § 20 |

## Feature F7.1 — Persistance de la CA interne Caddy

Inchangée depuis 06B v0.1 F8.1 (T8.1.1, T8.1.2), renumérotée sans modification de contenu.

## Feature F7.2 — Endpoint HTTP interne dédié pour `root.crt` (remplace l'ancien F8.2)

| Task | Action précise | Entrées | Sorties attendues | Dépend de | Critères d'acceptation | Sources |
| ---- | --------------- | ------- | -------------------- | ---------- | ------------------------ | ------- |
| T7.2.1 | Configurer, dans le fichier principal Caddy ou un fragment interne dédié non issu du registre applicatif, un bloc de site `ca.{{ staging_base_domain }}` servant en lecture seule le fichier exporté `root.crt` (`file_server`/`root`), actif uniquement si `caddy_tls_mode == internal` | SRC-004bis § 10.2, DEC-024 | Configuration Caddy exposant `http://ca.<staging_base_domain>/root.crt` | T7.1.1 (persistance CA) | En staging, `root.crt` est récupérable par requête HTTP simple ; en production, cette route n'existe pas | SRC-004bis § 10.2, § 10.3 |
| T7.2.2 | Documenter, dans le README (F11.1), la procédure de vérification d'empreinte SHA-256 recommandée côté consommateur | T7.2.1 | Section README | T7.2.1 | La procédure est décrite avec un exemple de commande | SRC-004bis § 10.2, RISK-006 |

## Feature F9.1 — CI de validation de forme et de schéma

Inchangée depuis 06B v0.1 F10.1, révisée pour couvrir les nouveaux invariants du schéma à trois niveaux (T1.2.1bis) et la précondition de préflight (F1.3).

## Feature F9.2 — Matrice de tests fonctionnels et journal de déploiement

| Task | Action précise | Entrées | Sorties attendues | Dépend de | Critères d'acceptation | Sources |
| ---- | --------------- | ------- | -------------------- | ---------- | ------------------------ | ------- |
| T9.2.1 | Consolider l'ensemble des scénarios de test (F1.3, F3.2, F5.1, F6.1) en un scénario exécutable unique | Ensemble des Tasks de test précédentes | Scénario consolidé | T5.1.3, T6.1.3 | Tous les scénarios listés en SRC-004bis § 20 sont couverts | SRC-004bis § 20 |
| T9.2.2 (nouveau) | Mettre en place le journal de déploiement append-only (playbook, paramètres, SHA consommé, résultat), hors VM proxy, jamais lu par le rôle | DEC-026, SRC-004bis § 9.7 | Mécanisme de journalisation (logs Ansible/CI structurés) | T1.3.1 | Chaque exécution de `converge-proxy.yml`/`converge-route.yml` produit une entrée de journal ; le rôle ne relit jamais ce journal pour décider | SRC-004bis § 9.7 |

## Feature F10.1 — Extraction et transformation des fiches existantes

| Task | Action précise | Entrées | Sorties attendues | Dépend de | Critères d'acceptation | Sources |
| ---- | --------------- | ------- | -------------------- | ---------- | ------------------------ | ------- |
| T10.1.1bis | Extraire chaque fiche `vars/projects/<x>.yml` vers `registry/<environnement>/<x>.yml`, avec un `published_service` (`service_id`, `listen_port: 443`, `frontend_protocol: https` par défaut pour le cas HTTP(S) standard) portant les routes migrées | HYP-005 vérifiée avant `webcam.yml` | Fiches migrées au format à trois niveaux | T1.2.1bis | Chaque fiche migrée passe la validation de schéma T1.2.1bis | SRC-004bis § 21 |
| T10.1.2 | Transformer chaque ancienne redirection (`redirects` racine) en route `handler: redirect` au sein du service concerné | T10.1.1bis | Fiches migrées avec redirections modélisées comme routes | T10.1.1bis | Aucune fiche migrée ne porte de champ `redirects` racine | SRC-004bis § 6.9, § 21 |
| T10.1.3 | Migrer le cas Matrix en une fiche unique à deux services (`matrix-client`, `matrix-federation`) | ARB-001 (résolu, plus d'hypothèse ouverte) | `registry/<environnement>/matrix.yml` | T10.1.1bis | La fédération Matrix est représentée sans champ ad hoc | SRC-004bis § 6.12.6 |

## Feature F10.2 — Retrait des anciennes responsabilités applicatives

Inchangée depuis 06B v0.1 F11.2 (T11.2.1, T11.2.2, T11.2.3), renumérotée sans modification de contenu.

## Feature F11.1 — README opérationnel du dépôt cible

Inchangée dans son principe depuis 06B v0.1 F12.1, révisée pour documenter : les deux playbooks (`converge-proxy.yml`, `converge-route.yml`) avec exemples d'appel à quatre paramètres pour le second, la séquence Git préalable obligatoire à toute convergence, l'endpoint `root.crt` et sa vérification d'empreinte (F7.2), l'absence d'index d'artefacts, la restriction Debian/Ubuntu.

## Feature F12.1 — Validation staging de bout en bout

Inchangée dans son principe depuis 06B v0.1 F13.1, avec ajout d'un test explicite du cas Matrix à deux services et de l'endpoint `root.crt`.

## Feature F12.2 — Préparation de la production

Inchangée dans son principe depuis 06B v0.1 F13.2, avec ajout à la checklist : vérification que les VM cibles sont bien Debian/Ubuntu (DEC-025), et qu'aucun bloc `ca.*` de distribution de CA staging n'est présent dans la configuration production (F7.2).

---

# 11. Granularité des Tasks

Inchangé depuis 06B v0.1 § 12, avec une règle supplémentaire :

| Règle de granularité | Application dans le plan | Justification |
| ----------------------- | --------------------------- | -------------- |
| Une Task de rendu de fragment ne mélange jamais la logique de plusieurs routes d'un même service avec la résolution PRESENT/ABSENT d'une route ciblée | T3.1.1bis/T3.1.2/T3.1.3 (rendu générique) sont strictement séparées de T5.1.2 (résolution du cas ciblé, qui invoque ensuite le rendu générique sur l'état déjà déterminé) | Évite qu'une modification du gabarit de rendu embarque silencieusement une logique de sélection de cas, et inversement |

---

# 12. Dépendances

Reprend 06B v0.1 § 13, avec les dépendances suivantes ajoutées :

* F1.3 (préflight) est un prérequis de F5.1 et F6.1, comme de F1.2 ;
* F7.2 (endpoint `root.crt`) dépend de F7.1 (persistance CA) et non plus d'un accès SSH applicatif ;
* F5.1 (convergence ciblée unifiée) ne dépend plus de deux chaînes de dépendances séparées (ajout et suppression) mais d'une seule.

---

# 13. Chemin critique

Inchangé dans son principe depuis 06B v0.1 § 14 : F1.1 → F1.2 → F1.3 → F2.1/F2.2 → F3.1 → F3.2 → F4.1/F4.2 → F5.1 → F6.1 → F7.1 → F7.2 → F9.1/F9.2 → F10.1/F10.2 → F11.1 → F12.1 → F12.2. La fusion F5.1/F6.1 raccourcit le chemin critique d'une étape par rapport à v0.1.

---

# 14. Plan de migration

Inchangé dans son principe depuis 06B v0.1 § 15, avec le mapping de champs révisé conformément à T10.1.1bis/T10.1.2/T10.1.3 (§ 10 ci-dessus).

---

# 15. Jalons

Reprend 06B v0.1 § 16, avec un jalon de moins du fait de la fusion EPIC-05/EPIC-06 ; le jalon « suppression conforme validée » de v0.1 est absorbé par le jalon « convergence ciblée validée » (couvrant PRESENT et ABSENT dans un même jalon).

---

# 16. Critères de validation

Inchangé depuis 06B v0.1 § 17, à l'exception du critère de « Feature terminée » pour F5.1, qui exige désormais que les cinq scénarios (PRESENT, ABSENT-service-présent, ABSENT-service-absent, no-op, incohérence) soient tous validés — contre deux scénarios séparés (ajout, suppression) répartis sur deux Features distinctes en v0.1.

---

# 17. Stratégie de tests

Reprend 06B v0.1 § 18, étendue par la matrice de tests détaillée en SRC-004bis § 20 (reproduite intégralement dans ce document de référence architecturale ; ce plan n'en duplique pas le contenu, cf. T9.2.1).

---

# 18. Risques de développement

Le tableau de 06B v0.1 § 19 reste valable pour RISK-001 à RISK-007 (numérotation architecture inchangée, cf. SRC-004bis § 18). S'y ajoutent :

| ID | Risque | Phase concernée | Impact | Prévention dans le plan | Source |
| -- | ------- | ------------------ | ------ | --------------------------- | ------ |
| RISK-008 | Convergence ciblée bloquée par une modification non commitée sans rapport avec la route visée | EPIC-05 | Retard d'une opération ciblée urgente | Documenté comme compromis assumé (F11.1) ; aucune option de contournement introduite | SRC-004bis § 17 |
| RISK-009 | Régénération complète d'un fragment de service lors d'une convergence ciblée sur une seule route | EPIC-05 | Une erreur de template impacterait toutes les routes du service concerné | `caddy validate` couvre systématiquement l'intégralité du fragment avant bascule (F4.1) | SRC-004bis § 18 |
| RISK-010 | Endpoint `root.crt` accessible sans authentification sur le réseau interne staging | EPIC-07 | Récupération du certificat public par un tiers non explicitement autorisé | Assumé : certificat public par nature, seule sa clé privée doit rester protégée (F7.1) | SRC-004bis § 18 |

Les anciens RISK-002 (suppression accidentelle) reste valable mais sa prévention change : il est désormais couvert par le préflight Git généralisé (F1.3) plutôt que par une garde spécifique au retrait.

---

# 19. Dette technique

## 19.1 Dette acceptable temporairement

Reprend 06B v0.1 § 20.1. La ligne relative aux endpoints de fédération Matrix (« non représentés dans le registre ») est **retirée** : ARB-001 résout définitivement ce point, Matrix est représentable nativement dès la V1 (§ 6.12.6 de SRC-004bis). La ligne relative à la méthode de récupération de `root.crt` (« non tranchée définitivement ») est également **retirée** : ARB-004 tranche définitivement en faveur de l'endpoint dédié.

Reste valable : `enabled` non implémenté (ARB-002 confirme ce choix comme définitif, non plus temporaire) ; protocole backend limité à `http` (ARB-003/D confirme ce choix comme définitif pour la V1, avec un chemin explicite vers une décision future dédiée plutôt qu'une simple tolérance).

## 19.2 Dette interdite

Le tableau de 06B v0.1 § 20.2 reste valable. S'y ajoute :

| Dette interdite | Pourquoi | Source |
| ------------------- | -------- | ------ |
| Tout playbook écrivant dans un fichier du registre Git, y compris pour un usage jugé pratique (auto-complétion, génération de squelette) | Contredit directement ARCH-CAND-010/014, principe absolu depuis 04E | SRC-004bis § 9.4 |
| Tout index, base ou fichier d'état persistant sur la VM proxy | Contredit directement le principe de non-persistance des états dérivables (ARCH-CAND-022) | SRC-004bis § 12 |
| Un fragment Caddy par route individuelle | Produit des adresses de site Caddy dupliquées, invalide à `caddy validate` | SRC-004bis § 8.3 |

---

# 20. Hypothèses

Reprend 06B v0.1 § 21. HYP-003 (accès SSH des rôles applicatifs à la VM proxy staging) est **retirée**, sans objet depuis DEC-024. S'ajoute :

| ID | Hypothèse | Impact sur le plan | Validation nécessaire avant |
| -- | ---------- | --------------------- | -------------------------------- |
| HYP-006 | Un profil AppArmor actif sur les VM Debian/Ubuntu cibles n'entrave pas le renommage atomique de `conf.d/` | Si faux, le mécanisme de bascule (F4.2) doit être révisé | Avant T13.2.1 (checklist production), sur l'infrastructure réelle |

---

# 21. Arbitrages requis

Tous les arbitrages ARB-001 à ARB-009 de 06B v0.1 § 22 sont **résolus** par l'échange du 2026-08-02 et retirés de ce tableau. Aucun arbitrage bloquant ne reste ouvert à l'issue de cette révision — cf. SRC-004bis § 22, qui constate la même clôture côté architecture.

---

# 22. Éléments volontairement exclus

Reprend 06B v0.1 § 23. S'y ajoutent :

| Élément exclu | Motif | Source |
| ---------------- | ------ | ------ |
| Support HTTPS entre Caddy et ses upstreams | Étudié en détail durant l'arbitrage, non retenu pour la V1 faute d'un modèle de stockage de CA personnalisée instrumenté | SRC-004bis § 10.5, ARCH-CAND-020 |
| Index ou base d'artefacts gérés sur la VM proxy | Contredit le principe de non-persistance des états dérivables | SRC-004bis § 12 |
| Systèmes autres que Debian/Ubuntu | Restriction humaine confirmée | SRC-004bis § 3.1 |
| Promotion automatique staging → production | Restriction humaine confirmée | SRC-004bis § 3.3, ARB-009 |

---

# 23. Contrôle des ajouts arbitraires

Le tableau de 06B v0.1 § 24 reste valable pour ses quatre entrées (README vide par répertoire, consolidation des tests, hypothèse `webcam.yml`, pipeline CI consolidé), toutes non affectées par l'arbitrage. Aucun nouvel ajout arbitraire n'a été introduit dans cette révision : chaque Task nouvelle ou modifiée de ce document est directement rattachée à un ARCH-CAND ou une clarification A-R de SRC-004bis.

---

# 24. Matrice de traçabilité finale (extrait des changements)

| Ancien identifiant (v0.1) | Nouvel identifiant (v0.2) | Nature du changement |
| --- | --- | --- |
| EPIC-05 (ajout/modification) + EPIC-06 (suppression) | EPIC-05 (convergence ciblée unifiée) | Fusion |
| EPIC-07 | EPIC-06 | Renommage (`converge-proxy.yml`) |
| EPIC-08 | EPIC-07 | Révisé (endpoint `root.crt`) |
| EPIC-09 | EPIC-08 | Renuméroté, inchangé |
| EPIC-10 | EPIC-09 | Renuméroté, étendu (journal de déploiement) |
| EPIC-11 | EPIC-10 | Renuméroté, mapping de champs révisé |
| EPIC-12 | EPIC-11 | Renuméroté, inchangé |
| EPIC-13 | EPIC-12 | Renuméroté, ajout contrainte Debian/Ubuntu |
| F5.1 + F6.1 | F5.1 | Fusion (T5.1.1 à T5.1.4) |
| F7.1 (playbook `apply-route.yml`) | T5.1.1 (`converge-route.yml`) | Renommage + fusion |
| F8.2 (`fetch`/`slurp`) | F7.2 (endpoint HTTP dédié) | Remplacement de mécanisme |
| — | F1.3 (préflight Git) | Nouvelle Feature |
| T3.1.1 | T3.1.1bis + T3.1.2 + T3.1.3 | Scindée (rendu / en-tête / nommage) |

---

# 25. Vérification de conformité du plan

| Exigence                     | Respectée | Référence | Source d'origine |
| ----------------------------- | --------- | ------------------------ | -------------------- |
| Documents recensés           | Oui | Section 1 | Méthodologie du template 06A |
| Choix justifiés, sources indiquées | Oui | Toutes les tables | § 5, § 6 du template 06A |
| Architecture non modifiée par ce plan | Oui | Aucune Task ne redéfinit un champ ou une décision ARCH-CAND de SRC-004bis | P-PLAN-001 |
| Schéma à trois niveaux | Oui | DEC-008bis, F1.2 | SRC-004bis § 6.4 |
| Garde Git généralisée | Oui | DEC-012bis, F1.3, EPIC-05, EPIC-06 | SRC-004bis § 9.4, § 9.5 |
| Playbooks fusionnés | Oui | DEC-020, F5.1 | SRC-004bis § 9.3, ARCH-CAND-023 |
| Absence d'index persistant | Oui | DEC-023, F3.1, F6.1 | SRC-004bis § 8.7, § 12 |
| Endpoint `root.crt` | Oui | DEC-024, F7.2 | SRC-004bis § 10.2 |
| Restriction Debian/Ubuntu | Oui | DEC-025, F2.2, F12.2 | SRC-004bis § 3.1 |
| Tous les arbitrages ARB-001 à ARB-009 clos, aucun report | Oui | Section 21 | SRC-011 (via SRC-004bis) |
| Ajouts arbitraires déclarés | Oui | Section 23 | § 24 du template 06A |

---

# 26. Niveau de confiance

| Domaine      | Niveau | Justification | Sources |
| ------------- | ------ | -------------- | ------- |
| Séquencement | Élevé | Ordre inchangé dans son principe, raccourci d'une étape par la fusion F5.1/F6.1 | SRC-004bis § 7.3, § 9.5 |
| Registre à trois niveaux | Élevé | Champs, granularité et invariants fixés explicitement, six exemples couvrant tous les cas (y compris Matrix) | SRC-004bis § 6 |
| Convergence ciblée unifiée | Élevé | Cinq cas comportementaux entièrement définis (PRESENT/ABSENT×2/no-op/incohérence), aucun cas résiduel non spécifié | SRC-004bis § 9.3 |
| Non-persistance des états dérivables | Élevé | Principe directement issu d'un risque déjà identifié en v0.2 (RISK-003), généralisé sans ambiguïté | SRC-004bis § 12 |
| TLS | Élevé | Méthode de distribution de `root.crt` tranchée définitivement ; seul le support HTTPS-upstream reste hors V1, explicitement et non par défaut d'arbitrage | SRC-004bis § 10.2, § 10.5 |
| Migration | Moyen | Mapping du schéma à deux niveaux vers trois niveaux à valider sur les fiches réelles ; la contradiction `deploy-matrix-stack.yml` reste hors périmètre plutôt que résolue factuellement | SRC-004bis § 21 |
| Tests | Élevé | Matrice étendue de façon exhaustive aux nouveaux cas de convergence ciblée | SRC-004bis § 20 |

---

# 27. Auto-contrôle obligatoire

```text
[x] Tous les documents reçus sont listés, y compris SRC-004bis et SRC-011.
[x] Chaque décision révisée porte une référence explicite vers 04E et l'arbitrage source.
[x] Aucune décision d'architecture n'a été modifiée par ce plan lui-même.
[x] Aucune nouvelle technologie n'a été introduite au-delà de ce que SRC-004bis prescrit.
[x] Tous les arbitrages ARB-001 à ARB-009 sont clos (section 21).
[x] La garde Git généralisée est respectée dans toutes les Tasks de convergence (F1.3, EPIC-05, EPIC-06).
[x] L'absence d'index persistant est respectée (aucune Task n'introduit de mécanisme d'état auxiliaire).
[x] La fusion EPIC-05/EPIC-06 est tracée explicitement (section 24), pas silencieuse.
[x] Les ajouts non sourcés restent limités aux quatre éléments déjà déclarés en v0.1 (section 23).
```

---

*Ce document constitue une proposition officielle de plan de développement révisé, produite selon la méthodologie du template `06A-planification-implementation-architecture-deepseek.md`, à partir de 04E. Il ne constitue ni une autorisation d'implémentation, ni un document d'architecture, ni une modification du dépôt, ni un ADR, ni un CDR définitif. Il doit être vérifié, normalisé et validé par l'opérateur humain avant toute exécution.*
