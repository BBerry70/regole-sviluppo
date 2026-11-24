#!/usr/bin/env bash
# backup-sfoltisci.sh <test|prod> [--prova] — cancella i backup vecchi su un server con lo script
# privilegiato /usr/local/sbin/backup-sfoltisci (regole e installazione in ops/sbin/README.md).
#   test = server 192.168.1.20 (cartelle TEST e DR); prod = server di PRODUZIONE.
#   --prova: elenca cosa verrebbe cancellato, senza cancellare.
# Gira anche da solo ogni domenica alle 04:30 (timer backup-sfoltisci.timer), se installato.
set -euo pipefail
. "$(dirname "$(readlink -f "$0")")/lib.sh"
PROD_SSH="${PROD_SSH:-claude@192.168.1.126}"
S=/usr/local/sbin/backup-sfoltisci
dove="${1:-}"; opz="${2:-}"
case "$opz" in ""|--prova) ;; *) ops_err "opzione sconosciuta: $opz"; exit 2 ;; esac
# shellcheck disable=SC2086  # $opz vuoto = nessun argomento (la regola sudo lo richiede)
case "$dove" in
  test)
    sudo -n -l "$S" $opz >/dev/null 2>&1 || { ops_err "manca $S nella regola sudo (ops/sbin/README.md)"; exit 3; }
    sudo -n "$S" $opz ;;
  prod)
    ops_ssh_prod_disponibile || { ops_err "accesso ssh a PRODUZIONE non disponibile"; exit 2; }
    ssh -o BatchMode=yes "$PROD_SSH" "sudo -n -l $S $opz >/dev/null 2>&1" \
      || { ops_err "manca $S nella regola sudo della PRODUZIONE (ops/sbin/README.md)"; exit 3; }
    ssh -o BatchMode=yes "$PROD_SSH" "sudo -n $S $opz" ;;
  *) ops_err "uso: ops/backup-sfoltisci.sh <test|prod> [--prova]"; exit 2 ;;
esac
