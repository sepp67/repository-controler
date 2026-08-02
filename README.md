# Repository Controller — reverse_proxy

Rôle Ansible de gestion déclarative de deux reverse proxies Caddy (staging,
production). Ne déploie aucune application — routage uniquement.

> Ceci est un README d'orientation minimal, présent dès la création de la
> structure du dépôt. Le README opérationnel complet (structure, contrat de
> champs du registre, commandes canoniques, procédure de suppression conforme
> à Git, dépendance de sauvegarde Caddy, méthode de récupération de
> `root.crt`) reste à rédiger une fois le rôle stabilisé — voir 06B v0.2,
> Feature F11.1.

## À lire avant toute intervention

1. **`CLAUDE.md`** — règles absolues et discipline de travail pour tout agent (humain ou IA) intervenant sur ce dépôt.
2. **`docs/04E-proposition-architecture-reverse-proxy-claude-v0_3.md`** — architecture technique de référence.
3. **`docs/06B-plan-developpement-deepseek-v0_2.md`** — plan de développement, ordre des tâches.
4. **`docs/MIGRATION-NOTES.md`** — faits vérifiés sur le dépôt source réel et données d'infrastructure confirmées.

## Structure

```text
.
├── inventories/{staging,production}/   # peuplé, valeurs réelles
├── registry/{staging,production}/      # peuplé partiellement (voir MIGRATION-NOTES.md)
├── playbooks/                          # vide — converge-proxy.yml, converge-route.yml
├── roles/reverse_proxy/                # vide — voir README.md de chaque sous-répertoire
├── schemas/                            # vide — registry-entry.schema.json
├── tests/                              # vide
├── docs/                               # spécifications de référence
└── CLAUDE.md                           # règles du projet pour l'agent
```
