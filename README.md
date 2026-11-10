# regole-sviluppo

Regole comuni per sviluppare, rilasciare e mantenere le applicazioni aziendali BBerry70.
Valgono per tutte le persone e per tutti gli agenti (Codex, Claude Code) che lavorano su questi progetti.

## Contenuto

| File | Cosa contiene |
| --- | --- |
| [PROCEDURA_SVILUPPO_TEST_PRODUZIONE_DR.md](PROCEDURA_SVILUPPO_TEST_PRODUZIONE_DR.md) | Procedura v1.2 TEST → PRODUZIONE → DR (9 ottobre 2026) |
| [REGOLE_AGENTI.md](REGOLE_AGENTI.md) | Come lavorano insieme Codex e Claude: rami, pull request, tag, segreti |
| [modelli/AGENTS_INTESTAZIONE.md](modelli/AGENTS_INTESTAZIONE.md) | Intestazione comune da mettere in cima all'`AGENTS.md` di ogni progetto |
| [modelli/CLAUDE.md](modelli/CLAUDE.md) | `CLAUDE.md` da copiare in ogni progetto: rimanda ad `AGENTS.md` |

La copia canonica della procedura resta sul server TEST:
`andrea@192.168.1.20:/opt/test/PROCEDURA_SVILUPPO_TEST_PRODUZIONE_DR.md`.
Questo repository ne conserva una copia versionata. Se le due copie differiscono, vale quella sul server
e questo repository va aggiornato con una pull request.

## Perimetro

| Progetto | Repository | Produzione | Regole |
| --- | --- | --- | --- |
| CARMA | [BBerry70/CARMA](https://github.com/BBerry70/CARMA) | 192.168.1.126:8000 | Procedura v1.2 + `AGENTS.md` del progetto |
| Delivery Planner | [BBerry70/delivery-planner](https://github.com/BBerry70/delivery-planner) | 192.168.1.126:8022 | Procedura v1.2 + `AGENTS.md` del progetto |
| SOFIA | [BBerry70/sofia](https://github.com/BBerry70/sofia) | 192.168.1.126:8020 | Procedura v1.2 + `AGENTS.md` del progetto |
| PRIST | [BBerry70/prist_mvp](https://github.com/BBerry70/prist_mvp) | 192.168.1.126:8090 | Procedura v1.2 + `AGENTS.md` del progetto |
| Agent marketing | SonyVine/agent-marketing-doppincolla | da definire | Procedura v1.2; referente Sonia |

Fuori perimetro: `BBerry70/CondominiApp`, seguito da un altro account. Queste regole non si applicano e non va modificato.

## Ambienti

| Ambiente | Host | Percorsi | Uso |
| --- | --- | --- | --- |
| PRODUZIONE | 192.168.1.126 | `/opt/acrm/app`, `/opt/delivery-planner`, `/opt/sofia/app`, `/opt/prist` | Solo rilasci approvati. Accesso ordinario in sola lettura. |
| TEST | 192.168.1.20 (ACRM-STANDBY) | `/opt/test/…` | Unico ambiente di sviluppo e collaudo. PostgreSQL TEST sulla porta 5433. |
| DR | 192.168.1.20 (ACRM-STANDBY) | `/opt/acrm/app` e percorsi fuori `/opt/test` | Riceve solo versioni verificate in produzione. Servizi con effetti esterni spenti fino al failover. |

## Dove stanno le cose

- **GitHub** è la fonte unica del codice. `main` = versione in produzione; ogni rilascio ha un tag `prod-AAAAMMGG`.
- **Server TEST** è dove si sviluppa e si collauda.
- **`X:\IA\progetti\<progetto>`** (in preparazione) contiene copie di sola consultazione di `main`, aggiornate solo con `git pull`.
- I file operativi (documenti, fogli, report) stanno fuori dalle cartelle del codice.
- Segreti (`.env`, chiavi, password) non stanno né su GitHub né su `X:`.
