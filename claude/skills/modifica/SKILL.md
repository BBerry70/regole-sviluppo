---
name: modifica
description: Dalla richiesta dell'utente alla pull request per CARMA o Delivery Planner, sviluppando e collaudando solo in TEST. Usare quando l'utente chiede una modifica, una correzione o una nuova funzione a un progetto del perimetro.
---

1. Leggere l'`AGENTS.md` del progetto e i documenti che richiama per l'area toccata.
2. `git switch main && git pull`, poi ramo `claude/<tema>-<AAAAMMGG>`.
3. Sviluppare con test automatici. Rispettare i controlli obbligatori del progetto (per Delivery Planner
   `scripts/check_stock_reservations.py` e gli altri richiesti da `AGENTS.md`).
4. Portare il ramo in TEST con `ops/test-applica.sh <ramo>` e verificare con `ops/test-verifica.sh`.
   Se questi script non esistono ancora, fermarsi e dirlo all'utente: non copiare file in TEST a mano.
5. Aprire la PR verso `main` con: cosa cambia, test eseguiti con esito, verifica in TEST, rischi, rollback
   (REGOLE_AGENTI §4).
6. Se la modifica aggiunge o cambia migrazioni del database: applicarle in TEST e dirlo nella PR; per la
   PRODUZIONE gli script di rilascio non le eseguono, quindi segnalarle nel riepilogo come passo dell'utente.
7. Chiudere con «pronto per il rilascio» e il riepilogo da approvare: PR, tag proposto
   (`prod-AAAAMMGG`), file che cambiano, migrazioni, rischi. Non unire la PR e non creare tag: dopo
   «approvo il rilascio di prod-AAAAMMGG» (anche con un orario) si procede con la skill `/rilascio`.
