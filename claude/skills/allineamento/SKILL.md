---
name: allineamento
description: Stato in sola lettura di tutti i progetti del perimetro (CARMA, Delivery Planner) su GitHub, TEST, PRODUZIONE e DR; segnala differenze e propone come risolverle. Usare quando l'utente chiede lo stato, l'allineamento o "cosa c'è in produzione".
---

1. Per ogni progetto in `~/lavoro/` che ha `ops/stato.sh`: `git -C <progetto> fetch -q`, poi `<progetto>/ops/stato.sh`.
2. Elencare anche le PR aperte (`gh pr list -R <repo>`) e i rami `claude/…` senza PR o più vecchi di 7 giorni.
3. Riassumere per progetto, in italiano e senza gergo:
   - modifiche presenti solo in TEST (file diversi da `main`);
   - PRODUZIONE diversa dall'ultimo tag `prod-…` (o non verificabile e perché);
   - DR indietro rispetto a PRODUZIONE;
   - PR e rami aperti da troppo tempo.
4. Per ogni differenza proporre l'azione (PR di salvataggio, `dr-aggiorna`, chiusura ramo). Non eseguire nulla
   che scriva su TEST, PRODUZIONE o DR senza che l'utente lo chieda.
