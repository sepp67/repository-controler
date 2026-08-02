# schemas/

Vide par construction.

Doit contenir `registry-entry.schema.json` (06B v0.2 Task T1.2.1bis) validant :

- les champs obligatoires et facultatifs de 04E § 6.5/§ 6.6 ;
- tous les invariants d'unicité de 04E § 6.11 (`project_name` par environnement,
  `service_id` par fiche, couple `frontend_protocol`/`listen_port` par fiche,
  `route_id` par service, `backend_id` par route) ;
- l'exclusivité `backends[]` / `redirect` selon `handler` (04E § 6.9) ;
- le format `[a-z0-9-]+` (sans `_`) de `project_name`, `service_id`, `route_id`, `backend_id`.

Les 9 fiches de `registry/staging/` et les 3 fiches de `registry/production/`
doivent toutes passer la validation dès l'écriture de ce schéma — elles servent
de jeu de test de référence.
