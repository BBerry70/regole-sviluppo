---
name: dr
description: Aggiornamento separato del DR di un progetto alla versione già verificata in PRODUZIONE, quando il DR è rimasto indietro (lo segnala /allineamento). Usare solo su richiesta esplicita dell'utente; nel rilascio normale il DR lo aggiorna /rilascio.
---

1. `ops/stato.sh` del progetto: individuare l'ultimo tag `prod-*` e verificare che la PRODUZIONE gli sia
   uguale. Se la PRODUZIONE è diversa dal tag, fermarsi e riportare le differenze: il DR riceve solo ciò che
   è verificato in PRODUZIONE.
2. `ops/dr-aggiorna.sh <tag> --prova`: mostrare all'utente i file che cambiano e chiedere conferma.
   `--accetta-differenze-produzione` solo se l'utente lo chiede dopo aver visto le differenze.
3. `ops/dr-aggiorna.sh <tag>`; poi `ops/stato.sh`: il DR deve risultare uguale alla PRODUZIONE.
4. Registrare l'aggiornamento nella scheda di rilascio del tag con una PR **senza unirla** (come /rilascio §6),
   indicando backup e `ripristina.sh`.
Se il progetto non ha `ops/dr-aggiorna.sh`: fermarsi e dirlo.
