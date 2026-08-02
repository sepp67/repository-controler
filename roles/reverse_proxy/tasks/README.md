# roles/reverse_proxy/tasks/

Vide par construction.

Fichiers attendus (04E § 7.3, 06B v0.2 EPIC-01 à EPIC-06) :

| Fichier | Rôle | Task 06B v0.2 |
| --- | --- | --- |
| `preflight.yml` | Vérification exécutable de la propreté Git du registre | T1.3.1 |
| `install.yml` | Installation et configuration globale de Caddy (Debian/Ubuntu) | T2.1.1, T2.2.2bis |
| `registry_load.yml` | Chargement/validation des fiches, résolution `domain → project_name` | T1.2.2bis |
| `fragment_render.yml` | Rendu d'un fragment de service (toutes ses routes courantes) | T3.1.1bis, T3.1.2, T3.1.3 |
| `candidate_build.yml` | Construction de l'espace candidat complet | F4.1 (06B v0.1, inchangée) |
| `candidate_validate.yml` | `caddy validate` sur l'espace candidat | F4.1 |
| `candidate_apply.yml` | Bascule atomique, reload conditionnel | F4.2 |
| `converge_route.yml` | Point d'entrée ciblé : PRESENT/ABSENT/no-op/incohérence | T5.1.2, T5.1.4 |
| `main.yml` | Point d'entrée de convergence complète transactionnelle | T6.1.2 |

Ne jamais faire écrire un de ces fichiers dans `registry/` (04E § 9.4, règle absolue).
