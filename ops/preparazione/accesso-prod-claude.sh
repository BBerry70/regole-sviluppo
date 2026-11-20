#!/usr/bin/env bash
# Da eseguire con sudo su PRODUZIONE (192.168.1.126). CLAUDE_CODE_SERVER_TEST.md §6.3.
# Crea l'utente dedicato `claude` in sola lettura sui percorsi applicativi, senza sudo, raggiungibile
# solo con la chiave dedicata e solo da 192.168.1.20.
#   sudo bash accesso-prod-claude.sh '<contenuto di claude_prod_ed25519.pub>'
# Idempotente. Non cambia proprietari né permessi esistenti: aggiunge solo ACL per l'utente claude.
set -euo pipefail
[ "$(id -u)" = 0 ] || { echo "Lanciare con sudo." >&2; exit 1; }
PUB="${1:?chiave pubblica mancante}"
case "$PUB" in ssh-ed25519\ *) ;; *) echo "Chiave pubblica non valida." >&2; exit 1 ;; esac
command -v setfacl >/dev/null || { echo "Manca setfacl (pacchetto acl): interrompo." >&2; exit 1; }

echo "1. Utente claude"
if id claude >/dev/null 2>&1; then
  echo "   esiste già: $(id claude)"
else
  adduser --disabled-password --gecos "Claude Code - sola lettura" claude >/dev/null
  echo "   creato: $(id claude)"
fi
if id -nG claude | tr ' ' '\n' | grep -qxE 'sudo|admin|adm|root|wheel'; then
  echo "   ATTENZIONE: claude è in un gruppo privilegiato ($(id -nG claude)): interrompo." >&2; exit 1
fi
[ ! -e /etc/sudoers.d/claude-ops ] || echo "   nota: /etc/sudoers.d/claude-ops esiste già (non toccato)"

echo "2. Chiave autorizzata (solo da 192.168.1.20, niente inoltri)"
install -d -m 700 -o claude -g claude /home/claude/.ssh
printf 'from="192.168.1.20",no-port-forwarding,no-X11-forwarding,no-agent-forwarding %s\n' "$PUB" > /home/claude/.ssh/authorized_keys
chown claude:claude /home/claude/.ssh/authorized_keys
chmod 600 /home/claude/.ssh/authorized_keys

segreti() { find "$1" \( -name '.env' -o -name '.env.*' -o -name '.env_*' -o -name 'db_config.json' -o -name 'runtime_secrets.json' -o -name '*.pem' -o -name '*.key' \) ! -name '.env.example' -print0; }
attraversa() { local p="$1"; while [ "$p" != "/" ]; do setfacl -m u:claude:X "$p"; p="$(dirname "$p")"; done; }

echo "3. Lettura dei percorsi applicativi (segreti esclusi)"
for app in /opt/acrm/app "$(readlink -f /opt/delivery-planner/current 2>/dev/null || true)"; do
  [ -n "$app" ] && [ -d "$app" ] || { echo "   assente: ${app:-/opt/delivery-planner/current}"; continue; }
  attraversa "$(dirname "$app")"
  setfacl -R -m u:claude:rX -m d:u:claude:rX "$app"
  segreti "$app" | xargs -0 -r setfacl -x u:claude
  echo "   $app: lettura concessa"
  # file segreti comunque leggibili da tutti: solo segnalati, non modificati
  segreti "$app" | xargs -0 -r -I{} find {} -maxdepth 0 -perm /o+r -printf '   ATTENZIONE leggibile da tutti: %p (%m)\n' || true
done

echo
echo "Fatto. Utente: $(id claude). Nessun sudo."
