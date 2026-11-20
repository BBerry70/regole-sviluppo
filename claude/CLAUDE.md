# Claude Code sul server TEST (ACRM-STANDBY, 192.168.1.20) — utente `claude`

Generato da `regole-sviluppo/claude/CLAUDE.md` (CLAUDE_CODE_SERVER_TEST.md §4). Per cambiarlo: PR su
regole-sviluppo, poi ricopiarlo in `~/.claude/CLAUDE.md`.

## Regole
- Procedura TEST → PRODUZIONE → DR v1.2 e `REGOLE_AGENTI.md` in `~/lavoro/regole-sviluppo`; poi
  l'`AGENTS.md` di ogni progetto. Struttura di lavoro: `CLAUDE_CODE_SERVER_TEST.md`.
- **Regola d'oro: ogni operazione del ciclo di vita passa dagli script `ops/` del progetto.** Se uno
  script manca o non copre il caso, prima lo si crea o estende con una PR, poi lo si usa. Niente comandi
  improvvisati su PRODUZIONE o DR.
- PRODUZIONE e DR: solo lettura, salvo gli script di rilascio dopo l'approvazione esplicita dell'utente
  per quel rilascio («approvo il rilascio di prod-AAAAMMGG»), che copre merge, tag, PRODUZIONE e DR (D3).
- Segreti: mai leggere, stampare o copiare `.env`, chiavi, token, `/etc/delivery-planner-test/*.env`;
  usarli solo tramite gli script e le applicazioni.
- Rami `claude/<tema>-<AAAAMMGG>`, consegna con PR verso `main`. Mai push su `main`.
- `sudo` mai diretto: solo gli script in `/usr/local/sbin/` elencati in `/etc/sudoers.d/claude-ops` (D1).

## Progetti (dettagli in `<progetto>/ops/ambienti.env`)

| Progetto | Clone | TEST (192.168.1.20) | PRODUZIONE (192.168.1.126) | DR (192.168.1.20) |
| --- | --- | --- | --- | --- |
| CARMA | `~/lavoro/CARMA` | `/opt/test/acrm/app`, `carma-test.service`, :18000, PG 5433/acrm | `/opt/acrm/app`, `acrm.service`, :8000 | `/opt/acrm/app`, servizi mascherati |
| Delivery Planner | `~/lavoro/delivery-planner` | `/opt/test/delivery-planner/current`, `delivery-planner-test.service`, :18022, PG 5433 | `/opt/delivery-planner/current`, `delivery-planner.service`, :8022 | `/opt/delivery-planner/current`, servizio mascherato |

## Comandi
- Stato di un progetto (solo lettura): `~/lavoro/<progetto>/ops/stato.sh`
- Skill: `/allineamento` (stato di tutti i progetti), `/modifica` (dalla richiesta alla PR).
