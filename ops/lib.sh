# Libreria comune degli script ops/ dei progetti (CLAUDE_CODE_SERVER_TEST.md §5).
# Si include con:  . "${REGOLE_SVILUPPO:-$HOME/lavoro/regole-sviluppo}/ops/lib.sh"
# Regole: nessun segreto nei log, nessuna lettura di .env, nessuna scrittura su PRODUZIONE o DR
# fuori dagli script di rilascio approvati.

set -o pipefail

OPS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ops_info()  { printf '%s\n' "$*"; }
ops_ok()    { printf '  [ok] %s\n' "$*"; }
ops_warn()  { printf '  [!!] %s\n' "$*"; }
ops_err()   { printf 'ERRORE: %s\n' "$*" >&2; }
ops_titolo(){ printf '\n== %s ==\n' "$*"; }

# Carica ops/ambienti.env del progetto (mappa non segreta) e verifica le variabili essenziali.
ops_carica_ambienti() {
  local progetto_dir="$1"
  local f="$progetto_dir/ops/ambienti.env"
  [ -r "$f" ] || { ops_err "manca $f"; return 2; }
  # shellcheck disable=SC1090
  . "$f"
  local v
  for v in PROGETTO REPO TEST_DIR TEST_SERVIZIO TEST_URL_SALUTE PROD_HOST PROD_DIR PROD_SERVIZIO PROD_URL_SALUTE DR_DIR; do
    [ -n "${!v:-}" ] || { ops_err "variabile $v mancante in $f"; return 2; }
  done
  OPS_PROGETTO_DIR="$progetto_dir"
}

# Codice HTTP di un URL (vuoto se non risponde entro il timeout, 15 s: il /api/health di Delivery Planner TEST ne impiega ~10).
ops_http() { curl -s -o /dev/null -m "${2:-15}" -w '%{http_code}' "$1" 2>/dev/null; }

# Stato di un servizio systemd locale.
ops_servizio_locale() { systemctl is-active "$1" 2>/dev/null || true; }

# Utente ssh verso PRODUZIONE: disponibile solo se la chiave dedicata è configurata.
ops_ssh_prod_disponibile() {
  [ -n "${PROD_SSH:-}" ] || return 1
  ssh -o BatchMode=yes -o ConnectTimeout=8 "$PROD_SSH" true >/dev/null 2>&1
}

# Ultimo tag prod-* (ordinamento per data di creazione).
ops_ultimo_tag_prod() {
  git -C "$OPS_PROGETTO_DIR" fetch -q --tags origin 2>/dev/null || true
  git -C "$OPS_PROGETTO_DIR" tag -l 'prod-*' --sort=-creatordate | head -1
}

# Confronto file per file tra un riferimento git e una cartella installata (locale o via ssh).
# Uso: ops_confronta <ref> <cartella> <etichetta> [utente@host]
ops_confronta() {
  local ref="$1" dir="$2" etichetta="$3" ssh="${4:-}"
  local args=(--repo "$OPS_PROGETTO_DIR" --ref "$ref" --dir "$dir" --etichetta "$etichetta")
  local e
  for e in ${CONFRONTO_ESCLUDI:-}; do args+=(--escludi "$e"); done
  [ -n "$ssh" ] && args+=(--ssh "$ssh")
  python3 -I "$OPS_LIB_DIR/confronta.py" "${args[@]}"
}
