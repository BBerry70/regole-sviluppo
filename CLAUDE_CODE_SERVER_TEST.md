# Claude Code sul server TEST: struttura di lavoro

Versione 0.1 — 20 novembre 2026. Bozza da approvare. Vale per CARMA e Delivery Planner; si estende agli
altri progetti del perimetro quando servirà.

## 1. Obiettivo

L'utente chiede una modifica in linguaggio naturale. Claude Code esegue da solo tutti i passaggi tecnici:
codice, migrazioni TEST, test, verifica funzionale, pull request, rilascio in PRODUZIONE dopo approvazione,
aggiornamento DR, allineamento GitHub. All'utente restano soltanto:

1. la richiesta;
2. l'approvazione esplicita del rilascio in PRODUZIONE (una frase, es. «approvo il rilascio di prod-20261125»);
3. le eventuali autorizzazioni di sicurezza (vedi §6).

Niente più copia e incolla di script in PowerShell o in sessioni ssh: Claude Code gira **sul server TEST**
e l'utente lo usa dal PC aprendo una sola sessione ssh (o VS Code Remote-SSH) e lanciando `claude`.

La procedura v1.2 resta invariata: TEST → test verdi → approvazione → PRODUZIONE → verifica → DR.

## 2. Dove gira e con quale utente

| Voce | Valore |
| --- | --- |
| Host | ACRM-STANDBY, 192.168.1.20 (TEST e DR) |
| Utente | `andrea` (da valutare un utente dedicato `claude`, vedi §9) |
| Area di lavoro | `~/lavoro/` |
| Accesso PRODUZIONE | ssh con chiave dedicata verso 192.168.1.126: lettura sempre, scrittura solo dagli script di rilascio |
| Accesso GitHub | `gh` autenticato con un token limitato ai repository BBerry70 del perimetro |

Prerequisito di rete: il server deve poter uscire in HTTPS verso Anthropic (Claude Code) e GitHub. Questo
supera la regola §2.8 di `COMANDI_POSTAZIONE_WINDOWS.md` («il server non scarica nulla da GitHub») per il solo
utente di lavoro di Claude Code: va approvato esplicitamente (decisione D2).

## 3. Struttura dei file

```
~/.claude/
  CLAUDE.md                 mappa dei sistemi e regole operative (generato da questo repository)
  settings.json             permessi: cosa è consentito, cosa chiede conferma, cosa è vietato
  skills/                   procedure richiamabili: /modifica, /rilascio, /dr, /allineamento

~/lavoro/
  regole-sviluppo/          questo repository: regole, procedura, modelli, script comuni
  CARMA/                    clone di BBerry70/CARMA (rami claude/…)
  delivery-planner/         clone di BBerry70/delivery-planner (rami claude/…)

<progetto>/ops/             in ogni repository: script standard del ciclo di vita (§5)
<progetto>/ops/ambienti.env mappa NON segreta: percorsi, porte, servizi, host per TEST/PROD/DR
<progetto>/doc/releases/    scheda di ogni rilascio (già usata da CARMA)
```

Tutto ciò che descrive *come* si lavora sta su GitHub. Sul server restano solo i segreti (§6) e i file
`~/.claude/` generati da qui.

## 4. Contenuto di `~/.claude/CLAUDE.md`

Breve, ma con tutto quello che serve per non ricostruire il contesto:

- tabella progetti → repository, percorso TEST, servizio systemd TEST, porta TEST, percorso PRODUZIONE,
  servizio e porta PRODUZIONE, percorso DR (da `ops/ambienti.env` di ogni progetto);
- rimando alla procedura v1.2 e a `REGOLE_AGENTI.md`;
- regola d'oro: **per ogni operazione del ciclo di vita usare gli script `ops/`**; se uno script manca o non
  copre il caso, prima si crea o si estende lo script con una PR, poi lo si usa. Niente comandi improvvisati
  su PRODUZIONE o DR;
- segreti: mai leggere, stampare o copiare `.env`, chiavi, token; usarli solo tramite gli script.

## 5. Script standard `ops/` (uguali in ogni progetto)

| Script | Cosa fa | Conferma utente |
| --- | --- | --- |
| `stato.sh` | Commit attivo in TEST, PRODUZIONE e DR; confronto con `main` e ultimo tag `prod-…`; salute dei servizi. Solo lettura | no |
| `test-applica.sh <ramo>` | Backup del TEST, copia del ramo nel percorso TEST preservando `.env` e dati, migrazioni sul solo DB TEST, riavvio servizio TEST | no |
| `test-verifica.sh` | Test automatici + smoke test sulle API principali (non solo `/health`) | no |
| `prod-rilascio.sh <tag>` | Preflight, backup codice e database verificato, distribuzione del tag, migrazioni, verifiche, rollback automatico se le verifiche falliscono, scheda in `doc/releases/` | **sì, ogni volta** |
| `prod-rollback.sh <tag-precedente>` | Ritorno alla versione precedente | **sì** |
| `dr-aggiorna.sh <tag>` | Porta su DR la versione verificata in PRODUZIONE, preserva configurazioni DR, servizi con effetti esterni spenti | **sì** (può stare nella stessa approvazione del rilascio) |

Una libreria comune (`regole-sviluppo/ops/lib.sh`) contiene le funzioni condivise: backup, esclusioni
(`.env`, dati, log), controlli di salute, log senza segreti. I numerosi script `apply_*_production.py` oggi
presenti in CARMA diventano casi particolari o vengono assorbiti da `prod-rilascio.sh`.

## 6. Permessi e segreti

### 6.1 `~/.claude/settings.json`

- **Consentiti senza conferma:** git sui rami `claude/…`, `gh pr …`, test, lettura log, `systemctl status`,
  `journalctl`, `curl` verso le porte TEST, `ops/stato.sh`, `ops/test-applica.sh`, `ops/test-verifica.sh`.
- **Con conferma:** `ops/prod-*.sh`, `ops/dr-aggiorna.sh`, ogni `ssh` verso 192.168.1.126 che non sia
  `ops/stato.sh`, merge di pull request, creazione di tag.
- **Vietati:** lettura di `.env`, chiavi e file segreti; `git push` su `main`; `rm -rf` fuori dall'area di
  lavoro; `sudo` diretto (solo tramite gli script autorizzati, vedi 6.2).

### 6.2 sudo — decisione D1

La procedura v1.2, regola 8, vieta «sudo senza password per comodità». Tre possibilità:

| Opzione | Come | Valutazione |
| --- | --- | --- |
| A. Password in un file segreto letto da Claude | Claude usa la password quando serve | **Sconsigliata.** Un file leggibile dall'utente con cui gira Claude è leggibile in ogni momento: l'«approvazione esplicita» non è applicabile tecnicamente e la password vale per qualsiasi comando sudo. |
| B. sudo senza password solo per pochi script fissi | Regola in `/etc/sudoers.d/` che consente senza password soltanto gli script `ops/` installati in `/usr/local/sbin/`, di proprietà di root e non modificabili da `andrea` | **Consigliata.** Claude non può usare sudo per altro; ogni uso passa comunque dalla conferma in Claude Code (6.1). Richiede una deroga scritta alla regola 8 limitata a questi script. |
| C. La password la digita l'utente | Quando serve sudo, Claude prepara tutto e si ferma; l'utente digita la password nel terminale di Claude Code | Massima sicurezza, qualche secondo di lavoro manuale per rilascio. |

### 6.3 Altri segreti

- `.env` di ogni ambiente: restano dove sono, usati dagli script e dalle applicazioni, mai letti da Claude.
- Chiave ssh dedicata TEST → PRODUZIONE per Claude Code, distinta da quella di Codex.
- Token GitHub *fine-grained* limitato ai repository del perimetro.

## 7. Skill (procedure richiamabili)

Stanno in `regole-sviluppo/skills/` e si installano in `~/.claude/skills/`.

- **/modifica** — dalla richiesta dell'utente alla PR: ramo `claude/<tema>-<data>`, sviluppo,
  `test-applica.sh`, `test-verifica.sh`, PR con test e rischi (REGOLE_AGENTI §4). Si ferma con «pronto per il
  rilascio» e il riepilogo da approvare.
- **/rilascio** — solo dopo approvazione esplicita: merge della PR, tag `prod-AAAAMMGG`, `prod-rilascio.sh`,
  verifica, scheda di rilascio, poi `dr-aggiorna.sh`. In caso di errore: rollback e rapporto.
- **/dr** — aggiornamento DR separato, quando serve.
- **/allineamento** — `stato.sh` su tutti i progetti: segnala differenze tra GitHub, TEST, PRODUZIONE e DR e
  propone come risolverle.

## 8. Allineamento costante con GitHub

- Ogni modifica nasce su un ramo e arriva in `main` solo tramite PR.
- PRODUZIONE riceve solo tag `prod-…`; DR solo tag già verificati in PRODUZIONE.
- `/allineamento` (anche pianificabile ogni mattina in sola lettura) segnala: modifiche presenti solo in TEST,
  PRODUZIONE diversa dall'ultimo tag, DR indietro rispetto a PRODUZIONE, rami aperti da troppo tempo.

## 9. Decisioni da prendere

| # | Decisione | Proposta |
| --- | --- | --- |
| D1 | Gestione di sudo | Opzione B, con deroga scritta alla regola 8 |
| D2 | Il server TEST esce verso GitHub e Anthropic per l'utente di Claude Code | Sì |
| D3 | Merge e tag li fa Claude dopo l'approvazione del rilascio, invece dell'utente dal sito | Sì: una sola approvazione copre merge, tag, PRODUZIONE e DR |
| D4 | Utente di sistema: `andrea` o un utente dedicato `claude` | Utente dedicato: permessi più stretti e log separati |

## 10. Avvio (una volta sola)

Passi dell'utente, dal PC:

1. `ssh andrea@192.168.1.20`
2. installare Claude Code sul server e fare il primo accesso (`claude`);
3. `gh auth login` con il token limitato;
4. `git clone https://github.com/BBerry70/regole-sviluppo ~/lavoro/regole-sviluppo`
5. `cd ~/lavoro/regole-sviluppo && claude`, poi scrivere: «Leggi CLAUDE_CODE_SERVER_TEST.md ed esegui la
   preparazione per CARMA e Delivery Planner.»

Da qui in avanti è Claude Code a: clonare i progetti, verificare accessi e percorsi reali, scrivere
`ops/ambienti.env`, gli script `ops/` e le skill, generare `~/.claude/CLAUDE.md` e `settings.json`, aprire le
PR e chiedere conferma solo dove previsto. Il primo collaudo è un rilascio «a vuoto» su TEST di CARMA
(`test-applica.sh` + `test-verifica.sh` sul `main` attuale), poi un piccolo rilascio reale.
