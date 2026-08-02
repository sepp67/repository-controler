# roles/reverse_proxy/templates/

Vide par construction.

Doit contenir :

- `Caddyfile.j2` — fichier principal statique, importe `conf.d/*.caddy` (04E § 8.2, Task T2.1.1)
- `fragment.caddy.j2` — un bloc de site par service publié, en-tête auto-descriptif obligatoire (04E § 8.3/§ 8.4, Tasks T3.1.1bis, T3.1.2, T3.1.3, T3.2.1bis)

Rappel de la règle de granularité : **un fragment par service publié**
(`<project_name>__<service_id>.caddy`), jamais par route individuelle — un
fragment par route produit des adresses de site Caddy dupliquées et échoue à
`caddy validate` (04E § 8.3, § 15).
