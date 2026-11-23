---
name: rilascio
description: Rilascio in PRODUZIONE e poi DR di una PR già collaudata in TEST (CARMA e Delivery Planner), subito o a un orario indicato. Usare SOLO dopo che l'utente ha scritto «approvo il rilascio di prod-AAAAMMGG» (o «approvo il rilascio» riferito a una PR precisa) in questa conversazione.
---

Decisione D3: una sola approvazione esplicita copre merge, tag, PRODUZIONE e DR di **quel** rilascio. Non vale
per altre PR, altri tag o altri giorni. Senza la frase di approvazione: fermarsi e chiederla, con il riepilogo.

## 0. Cosa si rilascia
- Progetto e PR: quelli dell'ultimo «pronto per il rilascio» di `/modifica`, o quelli nominati dall'utente.
  Se il progetto non ha `ops/prod-rilascio.sh`: fermarsi e dirlo (niente rilasci a mano).
- Nome del tag: `prod-AAAAMMGG` con la **data del rilascio in ora italiana** (`TZ=Europe/Rome date +%Y%m%d`,
  o la data pianificata); se esiste già, `-2`, `-3`, … Se l'utente ha scritto un nome di tag, usare quello.
- Orario: se l'utente indica un'ora («alle 17:45»), è ora italiana → rilascio pianificato (passo 4b).

## 1. Controlli prima del merge (sola lettura)
- `gh pr view <n> --json state,mergeable,headRefOid,baseRefName,files`: aperta, verso `main`, senza conflitti.
- Collaudo in TEST: `ops/test-verifica.sh` verde sullo stesso codice della PR (il commit applicato è in
  `<TEST_DIR>/.claude-applicato.json`). Per Delivery Planner comprende i controlli obbligatori di `AGENTS.md`
  (`check_stock_reservations.py`, `check_trip_addresses.py`): se falliscono non si rilascia. Se manca o è vecchio: `ops/test-applica.sh <ramo>` + `ops/test-verifica.sh`.
- Migrazioni: se la PR aggiunge o cambia file delle migrazioni (`TEST_MIGRAZIONI` in `ops/ambienti.env`),
  gli script di rilascio non le eseguono. Fermarsi e chiedere all'utente di applicarle al database di
  PRODUZIONE; proseguire con `--migrazioni-applicate` solo dopo la sua conferma scritta.
- Scheda di rilascio: la PR dovrebbe già contenere `doc/releases/<TEMA>_<AAAAMMGG>.md` (CARMA) o
  `docs/releases/<tema>/RELEASE.md` (Delivery Planner). Se manca, va bene: si crea al passo 6.

## 2. Merge e tag
1. `gh pr merge <n> --merge --delete-branch`, poi `git switch main && git pull --ff-only`.
2. `gh release create <tag> --target <sha del commit di merge> --title "<tag> <descrizione breve>" --notes "<riassunto, link PR>"`.
3. `git fetch --tags` e controllo: `git rev-parse <tag>^{commit}` = commit di merge, ed è l'ultimo tag `prod-*`.
Se il token GitHub non lo permette: fermarsi e dare all'utente i passi da fare sul sito (AGENTS.md del progetto).

## 3. TEST sul codice del tag
Se `main` conteneva altro oltre alla PR, il codice del tag è diverso da quello collaudato e `prod-rilascio.sh`
si ferma. In quel caso: `ops/test-applica.sh main` e `ops/test-verifica.sh`, che devono restare verdi.

## 4a. Rilascio subito
1. `ops/prod-rilascio.sh <tag> --prova`: mostrare all'utente i file che cambiano (sostituiti e nuovi).
   Se compaiono file inattesi, fermarsi e chiedere.
2. `ops/prod-rilascio.sh <tag>`: controlli, backup verificato di codice e database, copia, riavvio, verifiche.
   Se le verifiche nello script falliscono, lo script fa da solo il rollback e termina con errore.
3. Se termina con 0: `ops/dr-aggiorna.sh <tag>`. Se termina con errore: **niente DR**, passo 5.

## 4b. Rilascio pianificato (utente assente)
1. Fare il passo 4a.1 (`--prova`) subito e riportarne l'esito.
2. `~/lavoro/regole-sviluppo/ops/rilascio-pianificato.sh pianifica <progetto> <tag> "<AAAA-MM-GG HH:MM>"`
   con l'orario in ora italiana; riportare all'utente orario italiano e orario del server.
   Lo script lancia `prod-rilascio`, poi `dr-aggiorna` solo se il rilascio riesce, poi `stato.sh`;
   log in `~/ops-pianificati/<progetto>-<tag>.log`, che termina con la riga `===== … fine`.
3. Se la sessione resta aperta, pianificare con CronCreate un controllo ~15 minuti dopo l'orario: leggere il
   log (attendere se manca la riga `fine`), controllare che `rilascio-pianificato.sh elenco` non lo mostri
   più, mandare una PushNotification di una riga con l'esito, poi i passi 5–7.
   Annullare, se l'utente lo chiede: `rilascio-pianificato.sh annulla <progetto> <tag>`.

## 5. Se qualcosa va storto
- `prod-rilascio` in errore dopo la copia: lo script ha già rimesso i file; verificare con `ops/stato.sh`.
- Rilascio riuscito ma problemi rilevati dopo (salute, controlli rapidi, segnalazione dell'utente):
  `ops/prod-rollback.sh` (codice, non database), poi `ops/stato.sh`. Il DR resta alla versione precedente;
  se era già stato aggiornato, riportarlo indietro con il `ripristina.sh` del suo backup (serve sudo: comando
  per l'utente).
- Il database non si ripristina mai da soli: il dump nel backup resta per una decisione dell'utente.
- Rapporto all'utente: cosa è successo, cosa è stato rimesso, stato attuale.

## 6. Scheda di rilascio
Su un ramo `claude/registro-rilascio-<tag>-<AAAAMMGG>`, completare la scheda in `doc/releases/` (o
`docs/releases/`): approvazione, tag e commit, file installati, backup e dimensione del dump, controlli,
DR (backup e `ripristina.sh`), stato finale, eventuale rollback. Aprire la PR **senza unirla**.

## 7. Rapporto finale
Una sintesi in italiano: PRODUZIONE ok/rollback, DR ok/non fatto, backup, file, controlli, link alla PR della
scheda. Poi `ops/stato.sh` del progetto deve mostrare PRODUZIONE e DR uguali al nuovo tag.
