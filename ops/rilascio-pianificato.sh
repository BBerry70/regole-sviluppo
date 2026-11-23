#!/usr/bin/env bash
# rilascio-pianificato.sh — rilascio in PRODUZIONE (e poi DR) a un orario deciso dall'utente, anche in sua
# assenza, tramite il crontab dell'utente claude. Solo dopo l'approvazione esplicita di QUEL rilascio (D3).
#
#   rilascio-pianificato.sh pianifica <progetto> <tag> "<AAAA-MM-GG HH:MM>"   orario in ora italiana
#   rilascio-pianificato.sh elenco
#   rilascio-pianificato.sh annulla <progetto> <tag>
#   rilascio-pianificato.sh esegui <progetto> <tag> <AAAA-MM-GG>              (lo lancia cron)
#
# L'orario è sempre in ora italiana (Europe/Rome) e viene convertito nel fuso del server, qualunque sia.
# esegui: si toglie dal crontab appena parte, poi <progetto>/ops/prod-rilascio.sh <tag>; solo se riesce
# <progetto>/ops/dr-aggiorna.sh <tag>; infine ops/stato.sh. Log: ~/ops-pianificati/<progetto>-<tag>.log,
# che termina sempre con la riga «===== … fine».
set -uo pipefail
LAVORO="${LAVORO:-$HOME/lavoro}"
CARTELLA="$HOME/ops-pianificati"
SE_STESSO="$(readlink -f "$0")"
MARCA="rilascio-pianificato"
err() { echo "ERRORE: $*" >&2; exit 2; }

progetto_dir() {
  [[ "$1" =~ ^[A-Za-z0-9._-]+$ ]] || err "nome progetto non valido: $1"
  local d="$LAVORO/$1"
  [ -x "$d/ops/prod-rilascio.sh" ] || err "$d/ops/prod-rilascio.sh non esiste: progetto senza rilascio automatico"
  echo "$d"
}
controlla_tag() { [[ "$1" =~ ^prod-[0-9]{8}(-[0-9]+)?$ ]] || err "nome di tag non valido: $1"; }

azione="${1:-}"; shift || true
case "$azione" in
  pianifica)
    [ "$#" -eq 3 ] || err 'uso: pianifica <progetto> <tag> "<AAAA-MM-GG HH:MM>"'
    progetto="$1"; tag="$2"; quando="$3"
    d="$(progetto_dir "$progetto")" || exit 2; controlla_tag "$tag"
    [[ "$quando" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}\ [0-9]{2}:[0-9]{2}$ ]] || err "orario non valido: $quando"
    git -C "$d" fetch -q --tags origin
    c="$(git -C "$d" rev-parse -q --verify "refs/tags/$tag^{commit}")" || err "tag $tag inesistente"
    git -C "$d" merge-base --is-ancestor "$c" origin/main || err "$tag non è su main"
    ep="$(TZ=Europe/Rome date -d "$quando" +%s)" || err "orario non valido: $quando"
    [ "$ep" -gt "$(( $(date +%s) + 120 ))" ] || err "l'orario $quando (ora italiana) è già passato o troppo vicino"
    locale="$(date -d "@$ep" '+%M %H %d %m %F')"; read -r mi hh gg mm giorno <<<"$locale"
    crontab -l 2>/dev/null | grep -q "# $MARCA $progetto $tag\$" && err "$progetto $tag è già pianificato (vedi: elenco)"
    mkdir -p "$CARTELLA"; chmod 0700 "$CARTELLA"
    riga="$((10#$mi)) $((10#$hh)) $((10#$gg)) $((10#$mm)) * $SE_STESSO esegui $progetto $tag $giorno # $MARCA $progetto $tag"
    { crontab -l 2>/dev/null; echo "$riga"; } | crontab -
    echo "pianificato: $progetto $tag alle $quando ora italiana ($(date -d "@$ep" '+%F %H:%M %Z') ora del server)"
    echo "log: $CARTELLA/$progetto-$tag.log"
    ;;
  elenco)
    crontab -l 2>/dev/null | grep "# $MARCA " || echo "nessun rilascio pianificato"
    ;;
  annulla)
    [ "$#" -eq 2 ] || err "uso: annulla <progetto> <tag>"
    crontab -l 2>/dev/null | grep -q "# $MARCA $1 $2\$" || err "nessun rilascio pianificato per $1 $2"
    crontab -l 2>/dev/null | grep -v "# $MARCA $1 $2\$" | crontab -
    echo "annullato: $1 $2"
    ;;
  esegui)
    [ "$#" -eq 3 ] || err "uso: esegui <progetto> <tag> <AAAA-MM-GG>"
    progetto="$1"; tag="$2"; giorno="$3"
    mkdir -p "$CARTELLA"; exec >>"$CARTELLA/$progetto-$tag.log" 2>&1
    crontab -l 2>/dev/null | grep -v "# $MARCA $progetto $tag\$" | crontab -
    [ "$(date +%F)" = "$giorno" ] || { echo "===== $(date -Is) data diversa da $giorno: non eseguo"; echo "===== $(date -Is) fine"; exit 0; }
    export PATH=/usr/local/bin:/usr/bin:/bin REGOLE_SVILUPPO="${REGOLE_SVILUPPO:-$LAVORO/regole-sviluppo}"
    d="$(progetto_dir "$progetto")" || { echo "===== $(date -Is) fine"; exit 2; }
    cd "$d" || exit 2
    echo "===== $(date -Is) inizio rilascio pianificato $progetto $tag (utente $(id -un))"
    ops/prod-rilascio.sh "$tag"; e=$?
    echo "===== $(date -Is) prod-rilascio esito $e"
    if [ "$e" = 0 ]; then
      ops/dr-aggiorna.sh "$tag"; r=$?
      echo "===== $(date -Is) dr-aggiorna esito $r"
    else
      echo "===== DR non aggiornato perché il rilascio non è riuscito"
    fi
    ops/stato.sh
    echo "===== $(date -Is) fine"
    ;;
  *) sed -n 2,13p "$0"; exit 2 ;;
esac
