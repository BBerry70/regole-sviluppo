# Claude Code sul server TEST: struttura di lavoro

Versione 0.2 — 20 novembre 2026. Decisioni D1–D4 approvate dall'utente il 20/11/2026. Vale per CARMA e Delivery Planner; si estende agli
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
| Utente | `claude`, utente di sistema dedicato (D4). Non è `andrea` e non usa le chiavi di Codex |
| Area di lavoro | `~/lavoro/` |
| Accesso PRODUZIONE | ssh con chiave dedicata verso 192.168.1.126: lettura sempre, scrittura solo dagli script di rilascio |
| Accesso GitHub | `gh` autenticato con un token limitato ai repository BBerry70 del perimetro |

Rete (D2, approvata): l'utente `claude` del server TEST può uscire in HTTPS verso Anthropic (Claude Code) e
GitHub. Per questo utente non vale la regola §2.8 di `COMANDI_POSTAZIONE_WINDOWS.md` («il server non scarica
nulla da GitHub»), che resta valida per i comandi consegnati all'utente sul PC.

## 3. Struttura dei file

```
/home/claude/.claude/
  CLAUDE.md                 mappa dei sistemi e regole operative (generato da questo repository)
  settings.json             permessi: cosa è consentito, cosa chiede conferma, cosa è vietato
  skills/                   procedure richiamabili: /modifica, /rilascio, /dr, /allineamento

/home/claude/lavoro/
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

### 6.2 sudo — decisione D1 (approvata)

Deroga scritta alla regola 8 della procedura v1.2, limitata a quanto segue:

- l'utente `claude` può eseguire con sudo **senza password** soltanto gli script di rilascio installati in
  `/usr/local/sbin/` (copie degli script `ops/` approvati), di proprietà di `root:root`, permessi `0755`,
  non modificabili da `claude`;
- la regola sta in un solo file, `/etc/sudoers.d/claude-ops`, che elenca gli script per percorso assoluto;
  niente caratteri jolly, niente shell, niente editor;
- ogni uso passa comunque dalla conferma dell'utente in Claude Code (`settings.json`, 6.1);
- per aggiungere o cambiare uno script privilegiato: PR approvata, poi l'utente lo installa una volta con la
  propria password (comando preparato da Claude, un solo comando);
- la password di `andrea` e quella di root non vengono salvate in nessun file.

Esempio di `/etc/sudoers.d/claude-ops` (da adattare ai servizi reali):

```
claude ALL=(root) NOPASSWD: /usr/local/sbin/carma-prod-rilascio, /usr/local/sbin/carma-prod-rollback, /usr/local/sbin/carma-dr-aggiorna, /usr/local/sbin/carma-test-riavvia, /usr/local/sbin/dp-prod-rilascio, /usr/local/sbin/dp-prod-rollback, /usr/local/sbin/dp-dr-aggiorna, /usr/local/sbin/dp-test-riavvia
```

### 6.3 Altri segreti

- `.env` di ogni ambiente: restano dove sono, usati dagli script e dalle applicazioni, mai letti da Claude.
- Chiave ssh dedicata `claude@192.168.1.20` → PRODUZIONE, distinta da quella di Codex. Su PRODUZIONE la
  chiave apre un utente che può solo leggere e lanciare gli script di rilascio installati lì con la stessa
  regola sudo.
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

## 9. Decisioni (20/11/2026)

| # | Decisione | Esito |
| --- | --- | --- |
| D1 | Gestione di sudo | sudo senza password solo per gli script di rilascio root non modificabili, con deroga scritta alla regola 8 (§6.2) |
| D2 | Uscita del server TEST verso GitHub e Anthropic per l'utente di Claude Code | Approvata |
| D3 | Merge della PR e tag `prod-…` eseguiti da Claude | Approvata: una sola approvazione dell'utente («approvo il rilascio …») copre merge, tag, PRODUZIONE e DR. Da aggiornare la sezione «Chiusura di un rilascio» dell'`AGENTS.md` di CARMA |
| D4 | Utente di sistema | Utente dedicato `claude` |

### Perché un utente dedicato

- non vede le chiavi ssh, i file e la cronologia di `andrea` e di Codex;
- la regola sudo vale solo per lui: se servisse revocare tutto, basta disabilitare un utente;
- log, processi e file modificati sono attribuibili a Claude senza ambiguità;
- accede ai percorsi TEST tramite un gruppo (`carma-test`, `dp-test`) e non tocca DR (`/opt/acrm/app`) se non
  tramite gli script privilegiati.

## 10. Avvio (una volta sola)

Passi dell'utente, da una sessione `ssh andrea@192.168.1.20` aperta dal PC (servono la password di `andrea`
per sudo e l'accesso all'account Claude e a GitHub):

1. creare l'utente e dargli accesso ai percorsi TEST (Claude Code poi verifica e corregge i permessi di
   dettaglio, chiedendo conferma):
   ```
   sudo adduser --disabled-password --gecos "Claude Code" claude
   ```
2. passare all'utente: `sudo -iu claude`
3. installare Claude Code per l'utente `claude` seguendo la documentazione ufficiale e fare il primo accesso
   lanciando `claude`;
4. `gh auth login` con un token *fine-grained* limitato ai repository del perimetro;
5. `git clone https://github.com/BBerry70/regole-sviluppo ~/lavoro/regole-sviluppo`
6. `cd ~/lavoro/regole-sviluppo && claude`, poi scrivere: «Leggi CLAUDE_CODE_SERVER_TEST.md ed esegui la
   preparazione per CARMA e Delivery Planner.»

Nelle sessioni successive basta `ssh andrea@192.168.1.20`, `sudo -iu claude`, `claude` (oppure accesso ssh
diretto come `claude` con una chiave del PC, se preferito).

### Cosa fa Claude Code nella preparazione

1. clona i progetti, verifica percorsi, servizi, porte e database reali e scrive `ops/ambienti.env`;
2. prepara i gruppi e i permessi sui percorsi TEST e il file `/etc/sudoers.d/claude-ops`: consegna un solo
   comando da far eseguire all'utente con la sua password;
3. scrive gli script `ops/` e la libreria comune, li prova in TEST, apre le PR;
4. genera `~/.claude/CLAUDE.md`, `settings.json` e le skill;
5. aggiorna l'`AGENTS.md` di CARMA e Delivery Planner (D3, utente `claude`) e allinea la copia canonica
   della procedura sul server (`/opt/test/PROCEDURA_SVILUPPO_TEST_PRODUZIONE_DR.md`) con la deroga alla regola 8;
6. collaudo: `test-applica.sh` + `test-verifica.sh` sul `main` attuale di CARMA, poi un piccolo rilascio
   reale con la procedura completa.
