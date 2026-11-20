#!/usr/bin/env bash
# Preparazione una tantum dei permessi dell'utente `claude` sul server TEST (CLAUDE_CODE_SERVER_TEST.md §10, passo 2).
# Da lanciare dall'utente andrea, che inserisce la propria password di sudo:
#   sudo bash /home/claude/lavoro/regole-sviluppo/ops/preparazione/permessi-claude.sh [--chiudi-env-backup]
#
# Cosa fa (idempotente, nessun proprietario o permesso esistente viene cambiato, solo ACL aggiunte):
#  1. gruppi carma-test e dp-test, con dentro l'utente claude;
#  2. CARMA TEST: lettura e scrittura su /opt/test/acrm/app e /opt/test/acrm/backups (per test-applica.sh);
#     i file segreti (.env*, db_config.json) restano esclusi;
#  3. Delivery Planner TEST e DR: sola lettura del codice installato (per stato.sh);
#  3b. CARMA DR (/opt/acrm/app): sola lettura per il gruppo carma-test (stato.sh, dr-aggiorna.sh), segreti esclusi;
#  4. copia canonica della procedura: aggiunge la deroga alla regola 8 (D1) prendendo il testo da regole-sviluppo;
#  5. solo con --chiudi-env-backup: porta a 600 le copie di backup di .env leggibili da tutti in TEST e DR.
# Non crea /etc/sudoers.d/claude-ops: arriverà con gli script di rilascio approvati.
set -euo pipefail
[ "$(id -u)" = 0 ] || { echo "Lanciare con sudo." >&2; exit 1; }

CHIUDI_ENV=0
[ "${1:-}" = "--chiudi-env-backup" ] && CHIUDI_ENV=1

echo "1. Gruppi"
groupadd -f carma-test
groupadd -f dp-test
usermod -aG carma-test,dp-test claude

segreti() { find "$1" \( -name '.env' -o -name '.env.*' -o -name '.env_*' -o -name 'db_config.json' -o -name 'runtime_secrets.json' \) ! -name '.env.example' -print0; }

echo "2. CARMA TEST: lettura e scrittura (gruppo carma-test)"
setfacl -m g:carma-test:rX /opt/test/acrm
for d in /opt/test/acrm/app /opt/test/acrm/backups; do
  setfacl -R -m g:carma-test:rwX -m d:g:carma-test:rwX "$d"
  segreti "$d" | xargs -0 -r setfacl -x g:carma-test
done

echo "3. Delivery Planner TEST e DR: sola lettura (gruppo dp-test)"
for base in /opt/test/delivery-planner /opt/delivery-planner; do
  setfacl -m g:dp-test:rX "$base"
  cur="$(readlink -f "$base/current")"
  # attraversamento delle cartelle fra base e release corrente
  p="$cur"; while [ "$p" != "$base" ] && [ "$p" != "/" ]; do setfacl -m g:dp-test:rX "$p"; p="$(dirname "$p")"; done
  setfacl -R -m g:dp-test:rX -m d:g:dp-test:rX "$cur"
  segreti "$cur" | xargs -0 -r setfacl -x g:dp-test
done

echo "3b. CARMA DR: sola lettura (gruppo carma-test)"
setfacl -m g:carma-test:rX /opt/acrm
setfacl -R -m g:carma-test:rX -m d:g:carma-test:rX /opt/acrm/app
segreti /opt/acrm/app | xargs -0 -r setfacl -x g:carma-test

echo "4. Procedura canonica: deroga D1 alla regola 8"
CAN=/opt/test/PROCEDURA_SVILUPPO_TEST_PRODUZIONE_DR.md
NUOVA=/home/claude/lavoro/regole-sviluppo/PROCEDURA_SVILUPPO_TEST_PRODUZIONE_DR.md
if grep -q "Unica deroga (20/11/2026)" "$CAN"; then
  echo "   già aggiornata"
else
  diff "$CAN" "$NUOVA" || true
  read -r -p "   Applicare la differenza mostrata sopra? [s/N] " r
  if [ "$r" = s ]; then
    cp -p "$CAN" "$CAN.prima-deroga-D1-$(date +%Y%m%d%H%M%S)"
    cat "$NUOVA" > "$CAN"     # proprietario e permessi restano quelli attuali
    echo "   aggiornata (copia precedente salvata accanto)"
  else
    echo "   saltata"
  fi
fi

if [ "$CHIUDI_ENV" = 1 ]; then
  echo "5. Backup di .env leggibili da tutti -> 600"
  for d in /opt/test/acrm/app /opt/acrm/app; do
    find "$d" -maxdepth 1 \( -name '.env.*' -o -name '.env_*' \) ! -name '.env.example' -perm /o+r -print -exec chmod 600 {} +
  done
fi

echo
echo "Fatto. L'utente claude deve aprire una nuova sessione (sudo -iu claude) perché i gruppi abbiano effetto."
