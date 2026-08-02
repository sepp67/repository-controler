# Notes de migration — faits vérifiés sur le dépôt source réel

Ce document consigne les faits établis en analysant le contenu réel de
`devops_staging_prod_infra` (et des rôles associés `ansible-role-matrix-stack`,
`ansible-role-element-web`), lors de la préparation de ce dépôt. Il sert de
mémoire durable pour ne pas re-vérifier ce qui l'a déjà été, et pour ne pas
recréer silencieusement une incertitude déjà résolue.

## Arbitrages et hypothèses résolus factuellement

| ID | Question | Résolution factuelle |
| --- | --- | --- |
| ARB-007 (04E § 21) | `deploy-matrix-stack.yml` existe-t-il réellement ? | **Non.** Les playbooks racine sont uniquement `deploy-apps.yml`, `deploy-proxy.yml`, `deploy-docker-host.yml`, `site.yml`. Le déploiement Matrix est entièrement intégré dans `deploy-apps.yml` (plays 4 à 8 : PostgreSQL, Synapse Users, Synapse Bridges, bridges Mautrix, Element Web). L'audit par listing exhaustif était correct. |
| ARB-008 (04E § 21) | Contenu réel du rôle `element_web` ? | Vérifié directement : aucune référence à `root.crt`/CA/trust store dans ce rôle — cohérent avec un client web statique servi en HTTPS standard, sans besoin de confiance envers la CA interne Caddy. Le contrat de routage (domaine, backend, port) est entièrement connu via `vars/projects/element-web.yml` + `group_vars`, sans avoir besoin d'inspecter le rôle plus avant. |
| HYP-005 (04E § 23) | `webcam.yml` porte-t-il réellement un domaine routé ? | **Confirmé vrai.** La fiche déclare `domain: "{{ webcam_domain }}"` et `route_path: /`, malgré son déploiement sur une VM dédiée (réseau caméra séparé). Migrée normalement. |
| — | `active_projects` est-il un reliquat non chargé ? | **Faux — correction apportée à 06B v0.1 T11.2.2.** `active_projects` est activement lu et bouclé dans `deploy-proxy.yml` et `deploy-apps.yml` : c'est le mécanisme central de sélection des projets actifs dans l'ancien dépôt. Seul `vars/environments/*.yml` est un authentique reliquat (aucune référence trouvée ailleurs que dans ses propres commentaires). |

## Donnée réelle qui corrige un exemple illustratif de 04E

04E § 6.12.6 illustre Matrix avec des ports backend différents pour le client
(8008) et la fédération (8448), à titre d'exemple générique. **La donnée
réelle est différente** : dans `vars/projects/matrix-users-federation.yml` et
`vars/projects/matrix-bridges-federation.yml`, le champ `host_port` reprend la
**même** valeur que le service client (`matrix_users_http_port` = 8008,
`matrix_bridges_http_port` = 8009). Le homeserver Synapse expose donc client
et fédération sur un seul port HTTP interne ; seul le port d'écoute Caddy
diffère (443 vs 8448). Les fiches migrées dans `registry/*/matrix-users.yml`
et `registry/*/matrix-bridges.yml` reflètent cette réalité, pas l'exemple
générique de 04E.

## Infrastructure confirmée

| Élément | Staging | Production |
| --- | --- | --- |
| VM proxy (nouvelle, dédiée au Control Repository) | `192.168.1.93` | `192.168.1.95` |
| `caddy_tls_mode` | `internal` | `acme` |
| `caddy_acme_email` | — | `admin@lavallee.tech` (valeur réelle du dépôt source) |
| Domaine endpoint `root.crt` (04E § 10.2) | `ca.gites.local` | (non applicable) |

Ces VM (`.93`/`.95`) sont **distinctes** des anciennes VM proxy du dépôt
source (`vm-proxy-staging` = `192.168.1.56`, `vm-proxy-prod` = `192.168.1.69`,
cette dernière elle-même un placeholder `TODO` jamais résolu dans le dépôt
source). Ne pas confondre les deux lors d'une éventuelle consultation croisée
du dépôt source.

**Non vérifié à ce stade** (04E § 23, HYP-002/HYP-006) : provisionnement
effectif et accessibilité Ansible des VM `.93`/`.95`, version exacte de l'OS,
statut AppArmor. À vérifier avant toute exécution réelle d'un playbook.

## Placeholders de production non résolus

Les backends suivants sont encore des valeurs `TODO` **dans le dépôt source
réel lui-même** (pas seulement dans ce Control Repository) :

| Projet | Variable | Valeur placeholder actuelle |
| --- | --- | --- |
| `lavallee-website`, `facturier` | `backend_host` (apps) | `192.168.1.70` |
| `nextcloud` | `nextcloud_backend_host` | `192.168.1.71` |
| `webcam` | `webcam_backend_host` | `192.168.1.73` |
| `keycloak` | `keycloak_backend_host` | `192.168.1.85` |

Tant que ces valeurs ne sont pas confirmées par l'opérateur comme réelles (et
non plus des placeholders), **ne pas créer** les fiches `registry/production/`
correspondantes. `matrix-users`, `matrix-bridges` et `element-web` n'ont pas
cette réserve : leurs valeurs de production sont déjà réelles, sans `TODO`.

## Cas particuliers de migration déjà traités

- **`facturier`** : fusion de deux anciens projets (`facturier-app`,
  `facturier-landing`) partageant le même domaine, en une seule fiche à trois
  routes (`landing`, `application`, `api`) sur un seul service — cas réel
  ayant directement motivé la révision du modèle de registre vers
  « une fiche = un domaine, plusieurs routes » (04E § 6.1).
- **`nextcloud`** : les deux redirections WebDAV (`carddav`/`caldav`) de
  l'ancien champ racine `redirects` sont devenues des routes
  `handler: redirect`, placées avant la route générique `/` (04E § 6.9).
- **`grav-docs`** : confirmé **staging uniquement** — commenté dans
  `active_projects` de `inventories/production/group_vars/all/main.yml`.
  Aucune fiche production ne doit être créée pour ce projet.
