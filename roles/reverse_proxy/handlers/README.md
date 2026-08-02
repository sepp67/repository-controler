# roles/reverse_proxy/handlers/

Vide par construction.

Doit contenir le handler de reload Caddy (`systemctl reload caddy`, jamais
`restart`), déclenché uniquement après une bascule atomique réussie et
seulement si un changement réel est détecté — 04E § 8.6.
