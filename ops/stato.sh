#!/usr/bin/env bash
# stato.sh — solo lettura. Confronta TEST, PRODUZIONE e DR di un progetto con `main` e con l'ultimo tag prod-*.
# Uso: ops/stato.sh <cartella del progetto>   (gli script ops/stato.sh dei progetti richiamano questo)
set -u
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

progetto_dir="$(cd "${1:?cartella del progetto}" && pwd)"
ops_carica_ambienti "$progetto_dir" || exit 2

git -C "$progetto_dir" fetch -q origin main 2>/dev/null || ops_warn "fetch di origin/main non riuscito"
tag="$(ops_ultimo_tag_prod)"
ops_titolo "$PROGETTO — main $(git -C "$progetto_dir" rev-parse --short origin/main), ultimo tag ${tag:-nessuno}"

esito=0

ops_titolo "TEST ($TEST_DIR)"
s="$(ops_servizio_locale "$TEST_SERVIZIO")"; [ "$s" = active ] && ops_ok "servizio $TEST_SERVIZIO: $s" || { ops_warn "servizio $TEST_SERVIZIO: $s"; esito=1; }
c="$(ops_http "$TEST_URL_SALUTE")"; [ "$c" = 200 ] && ops_ok "salute $TEST_URL_SALUTE: $c" || { ops_warn "salute $TEST_URL_SALUTE: ${c:-nessuna risposta}"; esito=1; }
if [ -r "$TEST_DIR" ] && [ -x "$TEST_DIR" ]; then
  # Gli adattamenti di TEST salvati su GitHub (TEST_OVERLAY, es. CARMA) non sono differenze.
  CONFRONTO_OVERLAY="${TEST_OVERLAY:-}" ops_confronta origin/main "$TEST_DIR" "TEST vs main" || esito=1
else
  ops_warn "cartella TEST non leggibile dall'utente $(id -un): servono i permessi di gruppo (preparazione §10 passo 2)"; esito=1
fi

ops_titolo "PRODUZIONE ($PROD_HOST:$PROD_DIR)"
c="$(ops_http "$PROD_URL_SALUTE")"; [ "$c" = 200 ] && ops_ok "salute $PROD_URL_SALUTE: $c" || { ops_warn "salute $PROD_URL_SALUTE: ${c:-nessuna risposta}"; esito=1; }
if ops_ssh_prod_disponibile; then
  s="$(ssh -o BatchMode=yes "$PROD_SSH" systemctl is-active "$PROD_SERVIZIO" 2>/dev/null || true)"
  [ "$s" = active ] && ops_ok "servizio $PROD_SERVIZIO: $s" || { ops_warn "servizio $PROD_SERVIZIO: $s"; esito=1; }
  [ -n "$tag" ] && { ops_confronta "$tag" "$PROD_DIR" "PRODUZIONE vs $tag" "$PROD_SSH" || esito=1; }
else
  ops_warn "accesso ssh a PRODUZIONE non disponibile (PROD_SSH='${PROD_SSH:-}'): file non confrontati"; esito=1
fi

ops_titolo "DR ($DR_DIR, servizi spenti)"
if [ -r "$DR_DIR" ] && [ -x "$DR_DIR" ]; then
  [ -n "$tag" ] && { ops_confronta "$tag" "$DR_DIR" "DR vs $tag" || esito=1; }
else
  ops_warn "cartella DR non leggibile dall'utente $(id -un)"; esito=1
fi

exit $esito
