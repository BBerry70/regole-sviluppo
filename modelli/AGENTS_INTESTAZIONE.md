<!-- Copiare questo blocco in cima all'AGENTS.md di ogni progetto, prima delle regole specifiche. -->
## Regole comuni (BBerry70/regole-sviluppo)

Questo progetto segue la procedura TEST → PRODUZIONE → DR v1.2 e le regole comuni per Codex e Claude Code
pubblicate in https://github.com/BBerry70/regole-sviluppo (`PROCEDURA_SVILUPPO_TEST_PRODUZIONE_DR.md`,
`REGOLE_AGENTI.md`). Copia canonica della procedura: `andrea@192.168.1.20:/opt/test/PROCEDURA_SVILUPPO_TEST_PRODUZIONE_DR.md`.

In sintesi:
- si sviluppa e si collauda solo in TEST (192.168.1.20, `/opt/test/…`); PRODUZIONE e DR restano immutati;
- `main` = versione in produzione, aggiornata solo da pull request approvate dall'utente; tag `prod-AAAAMMGG` a ogni rilascio;
- Codex lavora su rami `codex/…`, Claude su rami `claude/…`; nessuno modifica i rami dell'altro;
- nessun segreto nei repository o nelle copie su `X:`; mai dati TEST in PRODUZIONE.

Le regole specifiche di questo progetto seguono e, dove più restrittive, prevalgono.
