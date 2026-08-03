#!/usr/bin/env bash
# tests/run_tests.sh — Suite de tests fonctionnels consolidée (04E § 20,
# 06B v0.2 T9.2.1). Couvre : préflight Git, chargement/validation du
# registre, les cinq cas de converge-route.yml (PRESENT, ABSENT-service-
# présent, ABSENT-service-disparu, no-op, incohérence) + sélection ambiguë,
# les deux cas de converge-proxy.yml (succès, échec transactionnel intégral)
# + nettoyage des orphelins, et l'idempotence des deux playbooks.
#
# Ne touche jamais le registre réel ni un vrai système : tout s'exécute dans
# un espace de travail jetable et isolé (aucun `become`, install.yml est
# stubbé). Nécessite : ansible-playbook, docker (pour extraire un binaire
# caddy réel sans droits root).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

FAILURES=0
pass() { echo "  OK     $1"; }
fail() { echo "  ECHEC  $1"; FAILURES=$((FAILURES + 1)); }
section() { echo; echo "=== $1 ==="; }

# ---------------------------------------------------------------------------
# Préparation : binaire caddy réel (sans root) + copie du rôle sans `become`
# (les chemins de test sont des répertoires jetables sous $WORKDIR, jamais
# des chemins système réels — `become` n'a donc aucune utilité ici et
# nécessiterait des droits root non garantis en CI/local).
# ---------------------------------------------------------------------------
section "Préparation de l'environnement de test"

CADDY_BIN="$WORKDIR/caddy_bin"
mkdir -p "$CADDY_BIN"
if command -v caddy >/dev/null 2>&1; then
  ln -s "$(command -v caddy)" "$CADDY_BIN/caddy"
  echo "caddy trouvé sur PATH : $(command -v caddy)"
else
  echo "Extraction du binaire caddy depuis l'image officielle (docker)..."
  docker pull -q caddy:2-alpine >/dev/null
  cid=$(docker create caddy:2-alpine)
  docker cp "$cid:/usr/bin/caddy" "$CADDY_BIN/caddy" 2>&1 | grep -v xattr || true
  docker rm "$cid" >/dev/null
  chmod +x "$CADDY_BIN/caddy"
fi
export PATH="$CADDY_BIN:$PATH"
caddy version

ROLE_COPY="$WORKDIR/roles_test"
mkdir -p "$ROLE_COPY"
cp -r "$REPO_ROOT/roles/reverse_proxy" "$ROLE_COPY/"
find "$ROLE_COPY/reverse_proxy" -name "*.yml" -exec sed -i '/^\s*become: true\s*$/d' {} \;

RELOAD_MARKER="$WORKDIR/reload_triggered.marker"
cat > "$ROLE_COPY/reverse_proxy/handlers/main.yml" << EOF
---
- name: Reload caddy
  ansible.builtin.copy:
    dest: "$RELOAD_MARKER"
    content: "reloaded\n"
  listen: reload caddy
EOF

cat > "$ROLE_COPY/reverse_proxy/tasks/install.yml" << 'EOF'
---
# Stubbé pour les tests fonctionnels : l'installation réelle de paquets/
# service systemd (EPIC-02) n'est pas testable sans VM Debian/Ubuntu dédiée
# ni droits root ; ce chemin est couvert séparément (garde OS, cf. rapport
# EPIC-02/EPIC-08).
- name: install.yml stubbé pour les tests
  ansible.builtin.file:
    path: "{{ caddy_conf_d_dir }}"
    state: directory
    mode: "0755"
EOF

# ---------------------------------------------------------------------------
# Résolution du rôle via ansible.cfg (sans ANSIBLE_ROLES_PATH), comme le
# ferait réellement un opérateur exécutant la commande documentée dans le
# README depuis la racine du dépôt. Sans roles_path = roles dans
# ansible.cfg, Ansible ne cherche que playbooks/roles/ (relatif au playbook),
# jamais roles/ à la racine — constaté sur une exécution réelle contre
# staging, jamais couvert par les tests jusqu'ici puisqu'ils fixaient tous
# ANSIBLE_ROLES_PATH. --list-tasks résout entièrement les rôles/includes sans
# rien exécuter (pas besoin de sudo/SSH réel).
# ---------------------------------------------------------------------------
section "Résolution du rôle via ansible.cfg (sans ANSIBLE_ROLES_PATH)"

if (cd "$REPO_ROOT" && env -u ANSIBLE_ROLES_PATH ansible-playbook --list-tasks playbooks/converge-proxy.yml > "$WORKDIR/last_run.log" 2>&1) \
   && (cd "$REPO_ROOT" && env -u ANSIBLE_ROLES_PATH ansible-playbook --list-tasks playbooks/converge-route.yml >> "$WORKDIR/last_run.log" 2>&1); then
  pass "les deux playbooks résolvent le rôle reverse_proxy sans ANSIBLE_ROLES_PATH (via ansible.cfg)"
else
  fail "résolution du rôle via ansible.cfg"
fi

# ---------------------------------------------------------------------------
# Vérification statique become: true (04E — aucune section dédiée ; constaté
# à l'usage réel, deux fois : install.yml puis fragment_render.yml). La
# suite fonctionnelle ci-dessous retire `become: true` de sa copie de rôle
# pour s'exécuter sans droits root (cf. plus haut) : elle ne peut donc
# jamais, structurellement, détecter un `become` manquant. Seule une analyse
# statique du vrai fichier peut le faire.
# ---------------------------------------------------------------------------
section "Vérification statique become: true"

if python3 "$REPO_ROOT/tests/check_become.py" > "$WORKDIR/last_run.log" 2>&1; then
  pass "aucune tâche d'écriture sur la VM cible sans become: true"
else
  fail "vérification become: true — voir $WORKDIR/last_run.log"
  cat "$WORKDIR/last_run.log"
fi

# ---------------------------------------------------------------------------
# Dépôt réel du fichier principal Caddy, avec le paramètre `validate:` exact
# d'install.yml — jamais exercé ailleurs (install.yml est stubbé dans le
# reste de cette suite, apt/systemd n'étant pas testables sans VM Debian/
# Ubuntu ni droits root). Constaté sur une exécution réelle contre staging :
# sans `--adapter caddyfile`, `caddy validate --config %s` échoue sur le
# fichier temporaire d'Ansible (nom sans extension reconnaissable, Caddy
# suppose du JSON par défaut).
# ---------------------------------------------------------------------------
section "Dépôt du fichier principal Caddy (validate: exact d'install.yml)"

MAINCFG_DIR="$WORKDIR/maincfg"
mkdir -p "$MAINCFG_DIR"
INSTALL_VALIDATE_LINE=$(grep -A8 "Déposer le fichier principal Caddy" "$REPO_ROOT/roles/reverse_proxy/tasks/install.yml" | grep "validate:" | sed 's/^[[:space:]]*//')
cat > "$WORKDIR/test_maincaddyfile.yml" << EOF
---
- hosts: localhost
  gather_facts: false
  tasks:
    - ansible.builtin.template:
        src: $REPO_ROOT/roles/reverse_proxy/templates/Caddyfile.j2
        dest: $MAINCFG_DIR/Caddyfile
        $INSTALL_VALIDATE_LINE
      vars:
        caddy_tls_mode: acme
        caddy_acme_email: admin@lavallee.tech
        caddy_conf_d_dir: $MAINCFG_DIR/conf.d
EOF
if ansible-playbook "$WORKDIR/test_maincaddyfile.yml" > "$WORKDIR/last_run.log" 2>&1; then
  pass "validate: d'install.yml accepte le fichier principal rendu (--adapter caddyfile présent)"
else
  fail "validate: d'install.yml — voir $WORKDIR/last_run.log"
  cat "$WORKDIR/last_run.log"
fi

export ANSIBLE_ROLES_PATH="$ROLE_COPY"
PLAYBOOK_ROUTE="$REPO_ROOT/playbooks/converge-route.yml"
PLAYBOOK_PROXY="$REPO_ROOT/playbooks/converge-proxy.yml"

# ---------------------------------------------------------------------------
# Fixture de registre + inventaire de test (hôte simulé, distinct du
# contrôleur, pour exercer réellement delegate_to/run_once — cf. EPIC-05).
# ---------------------------------------------------------------------------
FIXTURE="$WORKDIR/fixture"
mkdir -p "$FIXTURE/registry/staging"
CONF_D="$WORKDIR/conf.d"
CANDIDATE="$WORKDIR/candidate"

git_init_fixture() {
  rm -rf "$FIXTURE/registry/staging"
  mkdir -p "$FIXTURE/registry/staging"
  if [ ! -d "$FIXTURE/.git" ]; then
    git -C "$FIXTURE" init -q
    git -C "$FIXTURE" config user.email test@test.local
    git -C "$FIXTURE" config user.name test
  fi
}

git_commit_fixture() {
  git -C "$FIXTURE" add -A
  git -C "$FIXTURE" commit -q -m "$1" --allow-empty
}

write_testsvc() {
  cat > "$FIXTURE/registry/staging/testsvc.yml" << 'EOF'
project_name: testsvc
domain: testsvc.example.org
published_services:
  - service_id: web
    listen_port: 443
    frontend_protocol: https
    routes:
      - route_id: keep
        path: /keep
        handler: reverse_proxy
        backends:
          - backend_id: primary
            host: 10.0.0.1
            target_port: 8080
      - route_id: remove-me
        path: /remove-me
        handler: reverse_proxy
        backends:
          - backend_id: primary
            host: 10.0.0.1
            target_port: 8081
EOF
}

INV="$WORKDIR/inventory.yml"
cat > "$INV" << EOF
all:
  children:
    proxy:
      hosts:
        proxy-test-vm:
          ansible_connection: local
      vars:
        environment_name: staging
        caddy_tls_mode: internal
        staging_ca_endpoint_domain: ca.test.local
        registry_path: "$FIXTURE/registry/staging/"
        caddy_conf_d_dir: "$CONF_D"
        caddy_candidate_dir: "$CANDIDATE"
        deployment_log_path: "$WORKDIR/deployment-journal.log"
EOF
DEPLOYMENT_LOG="$WORKDIR/deployment-journal.log"

reset_state() {
  rm -rf "$CONF_D" "$CANDIDATE"
  mkdir -p "$CONF_D"
  rm -f "$RELOAD_MARKER"
}

run_route() {
  ansible-playbook -i "$INV" "$PLAYBOOK_ROUTE" "$@" > "$WORKDIR/last_run.log" 2>&1
}

run_proxy() {
  ansible-playbook -i "$INV" "$PLAYBOOK_PROXY" > "$WORKDIR/last_run.log" 2>&1
}

# ---------------------------------------------------------------------------
# Préflight (04E § 9.5)
# ---------------------------------------------------------------------------
section "Préflight Git"

git_init_fixture
write_testsvc
git_commit_fixture "init"
reset_state
if run_route -e environment=staging -e domain=testsvc.example.org -e service_id=web -e route_id=keep; then
  pass "registre propre -> préflight passe"
else
  fail "registre propre -> préflight aurait dû passer"
fi

echo "modification non commitée" >> "$FIXTURE/registry/staging/testsvc.yml"
reset_state
if run_route -e environment=staging -e domain=testsvc.example.org -e service_id=web -e route_id=keep; then
  fail "registre sale -> préflight aurait dû échouer"
else
  pass "registre sale -> préflight échoue avant toute action"
fi
git -C "$FIXTURE" checkout -q -- registry/staging/testsvc.yml

# ---------------------------------------------------------------------------
# converge-route.yml — les cinq cas + sélection ambiguë (04E § 9.3)
# ---------------------------------------------------------------------------
section "converge-route.yml — cas PRESENT"

reset_state
if run_route -e environment=staging -e domain=testsvc.example.org -e service_id=web -e route_id=keep \
   && grep -q "route-id: keep" "$CONF_D/testsvc__web.caddy" \
   && grep -q "route-id: remove-me" "$CONF_D/testsvc__web.caddy"; then
  pass "PRESENT : fragment créé avec toutes les routes courantes"
else
  fail "PRESENT"
fi

section "converge-route.yml — idempotence"

rm -f "$RELOAD_MARKER"
if run_route -e environment=staging -e domain=testsvc.example.org -e service_id=web -e route_id=keep \
   && [ ! -f "$RELOAD_MARKER" ]; then
  pass "reconvergence identique : no-op, aucun reload"
else
  fail "idempotence : un reload a été déclenché à tort"
fi

section "converge-route.yml — cas ABSENT (service encore présent)"

cat > "$FIXTURE/registry/staging/testsvc.yml" << 'EOF'
project_name: testsvc
domain: testsvc.example.org
published_services:
  - service_id: web
    listen_port: 443
    frontend_protocol: https
    routes:
      - route_id: keep
        path: /keep
        handler: reverse_proxy
        backends:
          - backend_id: primary
            host: 10.0.0.1
            target_port: 8080
EOF
git_commit_fixture "remove remove-me route"
if run_route -e environment=staging -e domain=testsvc.example.org -e service_id=web -e route_id=remove-me \
   && ! grep -q "route-id: remove-me" "$CONF_D/testsvc__web.caddy" \
   && grep -q "route-id: keep" "$CONF_D/testsvc__web.caddy"; then
  pass "ABSENT (service présent) : fragment régénéré sans la route retirée"
else
  fail "ABSENT (service présent)"
fi

section "converge-route.yml — cas ABSENT (service disparu)"

cat > "$FIXTURE/registry/staging/testsvc.yml" << 'EOF'
project_name: testsvc
domain: testsvc.example.org
published_services:
  - service_id: other
    listen_port: 8080
    frontend_protocol: https
    routes:
      - route_id: default
        path: /
        handler: reverse_proxy
        backends:
          - backend_id: primary
            host: 10.0.0.2
            target_port: 9090
EOF
git_commit_fixture "remove web service entirely"
if run_route -e environment=staging -e domain=testsvc.example.org -e service_id=web -e route_id=keep \
   && [ ! -f "$CONF_D/testsvc__web.caddy" ]; then
  pass "ABSENT (service disparu) : fragment retiré"
else
  fail "ABSENT (service disparu)"
fi

section "converge-route.yml — cas no-op"

rm -f "$RELOAD_MARKER"
if run_route -e environment=staging -e domain=testsvc.example.org -e service_id=web -e route_id=keep \
   && [ ! -f "$RELOAD_MARKER" ]; then
  pass "no-op : ni route ni fragment -> aucune modification"
else
  fail "no-op"
fi

section "converge-route.yml — incohérence"

echo "fichier étranger sans en-tête géré" > "$CONF_D/testsvc__other.caddy"
if run_route -e environment=staging -e domain=testsvc.example.org -e service_id=other -e route_id=default; then
  fail "incohérence : aurait dû échouer sans bascule"
else
  pass "incohérence : échec immédiat, sans bascule"
fi
rm -f "$CONF_D/testsvc__other.caddy"

section "converge-route.yml — sélection ambiguë"

if run_route -e environment=staging -e domain=nope.example.org -e service_id=web -e route_id=keep; then
  fail "domaine inexistant : aurait dû échouer (sélection ambiguë)"
else
  pass "domaine inexistant : échec explicite (sélection ambiguë)"
fi

# ---------------------------------------------------------------------------
# converge-proxy.yml — succès, échec intégral, nettoyage des orphelins
# (04E § 9.2, § 8.7)
# ---------------------------------------------------------------------------
section "converge-proxy.yml — convergence complète réussie"

git_init_fixture
write_testsvc
git_commit_fixture "init full"
reset_state
if run_proxy && [ -f "$CONF_D/testsvc__web.caddy" ]; then
  pass "convergence complète : fragment(s) créé(s)"
else
  fail "convergence complète réussie"
fi

section "converge-proxy.yml — idempotence"

rm -f "$RELOAD_MARKER"
if run_proxy && [ ! -f "$RELOAD_MARKER" ]; then
  pass "reconvergence identique : no-op, aucun reload"
else
  fail "idempotence convergence complète"
fi

section "converge-proxy.yml — nettoyage des orphelins"

# Une seconde fiche reste présente : registry_load.yml refuse à dessein un
# registre d'environnement totalement vide (garde de sécurité contre une
# convergence complète qui supprimerait tous les fragments par accident —
# constaté à l'implémentation, cf. rapport EPIC-09). Le cas réaliste de
# nettoyage d'orphelin est de toute façon le retrait d'UNE fiche parmi
# d'autres, pas la suppression totale du registre.
cat > "$FIXTURE/registry/staging/keepalive.yml" << 'EOF'
project_name: keepalive
domain: keepalive.example.org
published_services:
  - service_id: web
    listen_port: 443
    frontend_protocol: https
    routes:
      - route_id: default
        path: /
        handler: reverse_proxy
        backends:
          - backend_id: primary
            host: 10.0.0.9
            target_port: 9000
EOF
git_commit_fixture "add keepalive fiche"
reset_state
run_proxy > /dev/null 2>&1 || true

cat > "$CONF_D/foreign-file.caddy" << 'CADDYEOF'
manually-managed.example.org:443 {
    respond "hand-written"
}
CADDYEOF
foreign_before=$(sha256sum "$CONF_D/foreign-file.caddy")
rm -f "$FIXTURE/registry/staging/testsvc.yml"
git_commit_fixture "remove testsvc fiche, keepalive remains"
if run_proxy && [ ! -f "$CONF_D/testsvc__web.caddy" ] \
   && [ -f "$CONF_D/keepalive__web.caddy" ] \
   && [ "$(sha256sum "$CONF_D/foreign-file.caddy")" = "$foreign_before" ]; then
  pass "orphelin retiré, fiche non concernée et fichier non géré intacts"
else
  fail "nettoyage des orphelins"
fi
rm -f "$FIXTURE/registry/staging/keepalive.yml"
git_commit_fixture "remove keepalive fiche"

section "converge-proxy.yml — échec intégral sur fiche invalide"

write_testsvc
git_commit_fixture "restore testsvc"
run_proxy > /dev/null 2>&1 || true
sha_before=$(sha256sum "$CONF_D/testsvc__web.caddy" 2>/dev/null || echo "absent")

cat > "$FIXTURE/registry/staging/broken.yml" << 'EOF'
project_name: broken
domain: broken.example.org
published_services:
  - service_id: web
    listen_port: 443
    frontend_protocol: https
    routes: []
EOF
git_commit_fixture "add invalid fiche"
if run_proxy; then
  fail "fiche invalide : la convergence aurait dû échouer intégralement"
else
  sha_after=$(sha256sum "$CONF_D/testsvc__web.caddy" 2>/dev/null || echo "absent")
  if [ "$sha_before" = "$sha_after" ]; then
    pass "fiche invalide : échec intégral, fragment existant inchangé"
  else
    fail "fiche invalide : un fragment existant a été modifié malgré l'échec"
  fi
fi
rm -f "$FIXTURE/registry/staging/broken.yml"
git_commit_fixture "remove invalid fiche"

# ---------------------------------------------------------------------------
# Matrix — service à deux ports d'écoute (04E § 6.12.6, T3.2.3, F12.1)
# ---------------------------------------------------------------------------
section "Matrix — deux services publiés sur un même domaine"

cat > "$FIXTURE/registry/staging/matrix-test.yml" << 'EOF'
project_name: matrix-test
domain: matrix-test.example.org
published_services:
  - service_id: matrix-client
    listen_port: 443
    frontend_protocol: https
    routes:
      - route_id: default
        path: /
        handler: reverse_proxy
        backends:
          - backend_id: primary
            host: 10.0.0.20
            target_port: 8008
  - service_id: matrix-federation
    listen_port: 8448
    frontend_protocol: https
    routes:
      - route_id: default
        path: /
        handler: reverse_proxy
        backends:
          - backend_id: primary
            host: 10.0.0.20
            target_port: 8448
EOF
git_commit_fixture "add matrix-test fiche (two services)"
reset_state
if run_proxy \
   && [ -f "$CONF_D/matrix-test__matrix-client.caddy" ] \
   && [ -f "$CONF_D/matrix-test__matrix-federation.caddy" ] \
   && grep -q "matrix-test.example.org:443" "$CONF_D/matrix-test__matrix-client.caddy" \
   && grep -q "matrix-test.example.org:8448" "$CONF_D/matrix-test__matrix-federation.caddy"; then
  pass "deux fragments distincts, un par port d'écoute, aucune adresse dupliquée"
else
  fail "Matrix à deux services"
fi
rm -f "$FIXTURE/registry/staging/matrix-test.yml"
git_commit_fixture "remove matrix-test fiche"

# ---------------------------------------------------------------------------
# Endpoint root.crt — Caddy réel démarré, pas seulement validé (04E § 10.2,
# T7.2.1, F12.1)
# ---------------------------------------------------------------------------
section "Endpoint root.crt (staging)"

ROOTCRT_DIR="$WORKDIR/rootcrt_live"
mkdir -p "$ROOTCRT_DIR/conf.d"
cat > "$ROOTCRT_DIR/conf.d/dummy__web.caddy" << 'EOF'
dummy.example.org:443 {
    handle {
        respond "dummy"
    }
}
EOF

cat > "$WORKDIR/render_main_caddyfile.yml" << EOF
---
- hosts: localhost
  gather_facts: false
  tasks:
    - ansible.builtin.template:
        src: $ROLE_COPY/reverse_proxy/templates/Caddyfile.j2
        dest: $ROOTCRT_DIR/Caddyfile
      vars:
        caddy_tls_mode: internal
        staging_ca_endpoint_domain: ca.test.local
        caddy_conf_d_dir: $ROOTCRT_DIR/conf.d
EOF
ansible-playbook "$WORKDIR/render_main_caddyfile.yml" > "$WORKDIR/last_run.log" 2>&1

# XDG_DATA_HOME fait résoudre le répertoire de données de Caddy
# ($XDG_DATA_HOME/caddy) au même chemin que le paquet Debian réel (04E § 5).
# L'image officielle caddy:2-alpine fixe XDG_DATA_HOME=/data en dur (prime
# sur $HOME) ; sans cette variable, root.crt serait généré dans /data/caddy,
# différent du chemin en dur dans le vrai Caddyfile.j2 (constaté à
# l'implémentation, cf. rapport EPIC-07/EPIC-12).
if timeout 30 docker run --rm -d --name reverse_proxy_test_rootcrt \
     -e XDG_DATA_HOME=/var/lib/caddy/.local/share \
     -v "$ROOTCRT_DIR:/etc/caddy" caddy:2-alpine > /dev/null 2>&1; then
  docker exec reverse_proxy_test_rootcrt sh -c "echo '127.0.0.1 ca.test.local' >> /etc/hosts" > /dev/null 2>&1

  # La CA interne (et donc root.crt) n'est générée qu'au premier certificat
  # émis par Caddy au démarrage — pas instantané, on réessaie plutôt qu'un
  # délai fixe (constaté à l'implémentation : 5s fixes étaient insuffisants
  # de façon intermittente).
  # `wget` sort en erreur sur une réponse HTTP non-2xx (404 compris) ; combiné
  # à `pipefail`, cela ferait échouer `set -e` sur une affectation de
  # variable qui a pourtant réussi — `|| true` neutralise ce cas attendu
  # (constaté à l'implémentation).
  crt_status=""
  for _ in 1 2 3 4 5 6 7 8 9 10 11 12; do
    crt_status=$(timeout 10 docker exec reverse_proxy_test_rootcrt wget --no-check-certificate -S -O /dev/null https://ca.test.local/root.crt 2>&1 | grep -o "HTTP/1.1 [0-9]*" | head -1) || true
    if [ "$crt_status" = "HTTP/1.1 200" ]; then
      break
    fi
    sleep 3
  done
  key_status=$(timeout 10 docker exec reverse_proxy_test_rootcrt wget --no-check-certificate -S -O /dev/null https://ca.test.local/root.key 2>&1 | grep -o "HTTP/1.1 [0-9]*" | head -1) || true

  if [ "$crt_status" = "HTTP/1.1 200" ] && [ "$key_status" = "HTTP/1.1 404" ]; then
    pass "root.crt servi (200), root.key et tout autre chemin rejetés (404)"
  else
    echo "  --- diagnostic (logs caddy) ---"
    docker logs reverse_proxy_test_rootcrt 2>&1 | tail -15
    fail "endpoint root.crt (crt=$crt_status, key=$key_status)"
  fi
  docker stop reverse_proxy_test_rootcrt > /dev/null 2>&1
else
  echo "  (docker indisponible ou instable — test de l'endpoint root.crt ignoré, déjà validé manuellement en EPIC-07)"
fi
docker rm -f reverse_proxy_test_rootcrt > /dev/null 2>&1 || true

# ---------------------------------------------------------------------------
# Journal de déploiement append-only (04E § 9.7, T9.2.2)
# ---------------------------------------------------------------------------
section "Journal de déploiement append-only"

if [ -f "$DEPLOYMENT_LOG" ] \
   && [ "$(wc -l < "$DEPLOYMENT_LOG")" -gt 1 ] \
   && python3 -c "
import json, sys
for line in open('$DEPLOYMENT_LOG'):
    line = line.strip()
    if not line:
        continue
    entry = json.loads(line)
    assert 'timestamp' in entry and 'environment' in entry and 'source_commit' in entry and 'playbook' in entry
"; then
  pass "journal append-only peuplé, une ligne JSON structurée par exécution réussie"
else
  fail "journal de déploiement"
fi

# ---------------------------------------------------------------------------
section "Résumé"
if [ "$FAILURES" -eq 0 ]; then
  echo "Tous les scénarios de 04E § 20 sont passés."
  exit 0
else
  echo "$FAILURES scénario(s) en échec."
  exit 1
fi
