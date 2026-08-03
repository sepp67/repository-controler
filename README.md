# Repository Controller — reverse_proxy

Rôle Ansible de gestion déclarative de deux reverse proxies Caddy (staging,
production) pour l'infrastructure Lavallee. Ce dépôt ne déploie **aucune**
application — sa seule responsabilité est le routage HTTP/HTTPS déclaré dans
`registry/`.

## À lire avant toute intervention

1. **`CLAUDE.md`** — règles absolues et discipline de travail pour tout agent (humain ou IA) intervenant sur ce dépôt.
2. **`docs/04E-proposition-architecture-reverse-proxy-claude-v0_3.md`** — architecture technique de référence, seule source de vérité pour toute décision de conception.
3. **`docs/06B-plan-developpement-deepseek-v0_2.md`** — plan de développement, ordre des tâches.
4. **`docs/MIGRATION-NOTES.md`** — faits vérifiés sur le dépôt source réel et données d'infrastructure confirmées.

## Règle la plus structurante

**Aucun playbook ni tâche du rôle n'écrit jamais dans `registry/`**, dans
aucun mode d'exécution. Le registre est un artefact Git exclusivement modifié
par l'opérateur humain (édition, commit, push). Les playbooks se limitent à
faire converger l'état de Caddy vers l'état du registre déjà commité
(04E § 9.4, ARCH-CAND-010/014).

## Structure

```text
.
├── inventories/{staging,production}/   # hôtes proxy, variables d'environnement
├── registry/{staging,production}/      # source de vérité du routage — modifié uniquement par l'opérateur
├── playbooks/                          # converge-proxy.yml, converge-route.yml — les deux seuls playbooks publics
├── roles/reverse_proxy/                # rôle unique
├── schemas/                            # registry-entry.schema.json, validate_registry.py
├── tests/                              # run_tests.sh — suite de tests fonctionnels (04E § 20)
├── .github/workflows/ci.yml            # yamllint, schéma JSON, ansible-lint, syntax-check, tests fonctionnels
├── docs/                               # spécifications de référence
└── CLAUDE.md                           # règles du projet
```

## Modèle du registre (résumé)

Une fiche = un domaine (`registry/<environment>/<project_name>.yml`, le nom
de fichier doit correspondre exactement à `project_name`). Elle déclare un ou
plusieurs services publiés, chacun avec son propre port d'écoute et ses
routes :

```yaml
project_name: exemple            # [a-z0-9-]+, unique par environnement
domain: exemple.lavallee.tech    # FQDN complet, aucune composition implicite

published_services:
  - service_id: web              # [a-z0-9-]+, unique dans la fiche
    listen_port: 443
    frontend_protocol: https
    routes:
      - route_id: default        # [a-z0-9-]+, unique dans le service
        path: /                  # défaut "/"
        handler: reverse_proxy   # reverse_proxy | redirect, mutuellement exclusifs
        backends:
          - backend_id: primary
            host: 10.0.0.10      # jamais résolu via l'inventaire Ansible
            target_port: 8080    # transport implicite http, aucun champ protocol
```

`_` est interdit dans `project_name`/`service_id`/`route_id`/`backend_id`. Le
détail complet (invariants d'unicité, exemples multi-service/multi-route,
Matrix à deux ports) est dans 04E § 6. Le contrat exécutable est
`schemas/registry-entry.schema.json`, complété par les vérifications
`ansible.builtin.assert` de `roles/reverse_proxy/tasks/registry_load.yml`
(04E § 6.13).

## Séquence Git préalable, obligatoire

Le rôle ne modifie jamais le registre — c'est toujours l'opérateur qui
édite en premier :

```bash
$EDITOR registry/staging/mon-projet.yml
git add registry/staging/mon-projet.yml
git commit -m "mon-projet : ajoute la route /api"
git push
```

**Seulement ensuite**, exécuter le playbook. Toute convergence (ciblée ou
complète) vérifie d'abord que `registry/<environment>/` est strictement
propre en Git — aucune modification indexée, non indexée, ou fichier non
suivi, sur l'**ensemble** du répertoire de l'environnement, pas seulement le
fichier concerné (04E § 9.5). Un registre non propre fait échouer l'exécution
avant toute lecture applicative, sans option de contournement.

Pour **retirer** une route ou un service : `git rm`/éditer la fiche, commit,
push, puis exécuter `converge-route.yml` (retrait ciblé) ou
`converge-proxy.yml` (reflète l'état complet du registre). Ce n'est jamais le
rôle qui décide de retirer quoi que ce soit du registre.

## Commandes canoniques

### Convergence complète — `converge-proxy.yml`

Régénère l'intégralité des fragments attendus pour l'environnement de
l'inventaire chargé et exclut les fragments gérés devenus orphelins. Aucun
paramètre de sélection. Échoue intégralement si une seule fiche du registre
est invalide — aucune application partielle.

```bash
ansible-playbook -i inventories/staging/hosts.yml playbooks/converge-proxy.yml
```

### Convergence ciblée — `converge-route.yml`

Fait converger un seul service à partir d'une route identifiée. Comportement
PRESENT / ABSENT-service-présent / ABSENT-service-disparu / no-op /
incohérence, entièrement déterminé par l'état du registre (04E § 9.3). Les
quatre paramètres sont obligatoires.

```bash
ansible-playbook -i inventories/staging/hosts.yml \
  playbooks/converge-route.yml \
  -e environment=staging \
  -e domain=matrix-users.local \
  -e service_id=matrix-federation \
  -e route_id=default
```

`project_name` n'est jamais fourni directement : il est résolu depuis
`domain` (échec explicite si zéro ou plusieurs fiches correspondent).
`environment` doit correspondre à l'inventaire chargé via `-i` — un
désaccord fait échouer l'exécution avant toute action.

### Production — garde humaine obligatoire

**Ne jamais exécuter un playbook contre `inventories/production/` sans
validation humaine explicite, préalable et séparée de toute session de
développement.** Cette règle n'est pas techniquement appliquée par le rôle —
c'est une discipline opérateur.

## Checklist de préparation production (04E § 20-23, 06B v0.2 F12.2)

À vérifier avant la toute première convergence contre `inventories/production/`,
et à chaque changement d'infrastructure significatif :

1. **Validation humaine explicite, préalable et séparée** de toute session de
   développement (règle absolue, cf. ci-dessus) — jamais dans la continuité
   d'un travail sur staging.
2. **Staging validé de bout en bout d'abord**, contre la VM staging réelle
   (`inventories/staging/hosts.yml`), pas seulement `tests/run_tests.sh` (qui
   s'exécute sur un environnement jetable) : `converge-proxy.yml`, puis au
   moins un `converge-route.yml` ciblé, dans les deux sens (ajout et
   retrait).
3. **VM proxy production provisionnée et accessible en Ansible**
   (`ansible-playbook -i inventories/production/hosts.yml --list-hosts
   playbooks/converge-proxy.yml` répond) — sans quoi une étape de
   provisionnement séparée doit d'abord être clarifiée (HYP-002).
4. **Système Debian ou Ubuntu confirmé** sur la VM cible avant toute
   exécution (`ansible -i inventories/production/hosts.yml proxy -m setup -a
   'filter=ansible_distribution*'`) — le rôle le vérifie aussi lui-même
   (`tasks/install.yml`) et échoue explicitement sinon, mais une confirmation
   préalable évite une exécution partielle inutile (DEC-025, 04E § 3.1).
5. **Aucun bloc de distribution de CA staging (`ca.*`) ne doit apparaître
   dans la configuration production** : `caddy_tls_mode: acme` dans
   `inventories/production/group_vars/proxy.yml`, et
   `staging_ca_endpoint_domain` absent de ce même fichier — déjà le cas
   aujourd'hui, à revérifier après toute modification de l'inventaire
   production (04E § 10.3, F7.2).
6. **Registre production propre en Git et volontairement incomplet** :
   `registry/production/` ne contient que les fiches dont les valeurs
   d'infrastructure sont confirmées ; ne jamais y créer une fiche avec des
   valeurs inventées pour compléter la couverture (cf. `docs/MIGRATION-NOTES.md`).
7. **Sauvegarde du stockage persistant Caddy** en place pour la production
   (comptes ACME) avant la première convergence, si la conservation de
   l'identité TLS entre deux VM importe (§ 10.4) — dépendance opérationnelle
   externe à ce rôle.
8. **Compatibilité AppArmor à vérifier sur l'infrastructure réelle**
   (HYP-006) : un profil AppArmor actif ne doit entraver ni le renommage
   atomique de `conf.d/`, ni la lecture des fragments par le processus
   Caddy. Non vérifiable depuis un environnement de développement — à
   confirmer manuellement sur la VM production avant la première convergence
   complète.

## Endpoint `root.crt` (staging uniquement)

Caddy en staging utilise sa CA interne (`tls internal`) pour tous les
domaines. Le certificat public de cette CA est exposé, en lecture seule, via
un endpoint HTTP interne dédié — jamais présent en production (04E § 10.2,
§ 10.3) :

```text
http://<staging_ca_endpoint_domain>/root.crt
```

Où `staging_ca_endpoint_domain` est défini dans
`inventories/staging/group_vars/proxy.yml`. Seul le certificat public est
servi ; ni la clé privée, ni le reste du répertoire PKI ne sont accessibles
(vérifié : toute autre requête sur ce site renvoie 404).

**Le téléchargement se fait volontairement en HTTP, pas HTTPS** — acceptable
car seul un certificat public est distribué. Avant d'installer ce certificat
dans un trust store, tout rôle applicatif consommateur **doit** vérifier son
empreinte contre une valeur attendue connue par une source distincte de
l'endpoint lui-même (RISK-006) :

```bash
curl -s http://<staging_ca_endpoint_domain>/root.crt \
  | openssl x509 -noout -fingerprint -sha256
```

Comparer la sortie (`SHA256 Fingerprint=...`) à l'empreinte attendue avant
toute installation. Ce dépôt expose l'endpoint ; il ne vérifie jamais
lui-même l'empreinte à la place du consommateur (répartition des
responsabilités, 04E § 10.2).

## Absence d'index d'artefacts

Aucun fichier d'état, index ou base de données n'existe sur la VM proxy en
dehors des fragments Caddy eux-mêmes (`/etc/caddy/conf.d/*.caddy`). L'identité
d'un fragment repose exclusivement sur son nom de fichier
(`<project_name>__<service_id>.caddy`) et son en-tête auto-descriptif,
régénéré à chaque exécution — jamais sur un état persistant reconstruit entre
deux exécutions (04E § 8.4, § 8.7, § 12, principe de non-persistance des
états dérivables). Une VM proxy reconstruite retrouve exactement le même état
à partir du seul registre.

## Sauvegarde

La conservation de l'identité TLS (CA interne staging, comptes ACME
production) lors d'une reconstruction dépend d'une sauvegarde externe de
`/var/lib/caddy/.local/share/caddy/` — un mécanisme de sauvegarde **hors
périmètre de ce rôle** (04E § 10.4, ARCH-CAND-011). Sans cette sauvegarde,
une reconstruction fonctionnelle (Git + Ansible) reste possible, mais une
nouvelle CA staging est générée (`root.crt` à redistribuer) et les comptes
ACME production sont recréés.

## Systèmes cibles

Debian et Ubuntu exclusivement (04E § 3.1, ARCH-CAND-027). Toute tâche
d'installation vérifie l'OS et échoue explicitement sinon — aucune autre
distribution n'est supportée en V1, SELinux est hors périmètre.

## Tests et CI

```bash
yamllint -c .yamllint.yml registry/ inventories/
python3 schemas/validate_registry.py
ansible-lint roles/ playbooks/
bash tests/run_tests.sh
```

`tests/run_tests.sh` exécute la matrice de tests fonctionnels complète
(04E § 20) sur un environnement jetable — il ne touche jamais le vrai
registre ni un vrai système. Voir `tests/README.md`. Le tout est exécuté
automatiquement par `.github/workflows/ci.yml` sur chaque push/pull request.

## Journal de déploiement

Chaque exécution réussie de `converge-proxy.yml`/`converge-route.yml` ajoute
une ligne JSON append-only à `~/.reverse_proxy_deployment.log` (configurable
via `deployment_log_path`), côté contrôleur Ansible — jamais sur la VM proxy,
jamais relu par le rôle. Sert exclusivement à l'audit humain a posteriori
(04E § 9.7).
