# Regole comuni per Codex e Claude Code

Versione 1.0 — 10 novembre 2026. Si applicano insieme alla
[procedura v1.2](PROCEDURA_SVILUPPO_TEST_PRODUZIONE_DR.md) e all'`AGENTS.md` di ogni progetto.
In caso di conflitto prevalgono, nell'ordine: istruzioni esplicite dell'utente, procedura v1.2,
`AGENTS.md` del progetto, queste regole.

## 1. Fonte del codice e ambienti

- GitHub è la fonte unica del codice. Si sviluppa e si collauda soltanto in TEST (192.168.1.20, `/opt/test/…`).
- PRODUZIONE e DR non si modificano durante lo sviluppo. Ogni rilascio richiede l'approvazione esplicita
  dell'utente per quel rilascio, backup verificato e piano di rollback (procedura v1.2, sezioni C–E).
- Le copie su `X:\IA\progetti` sono di sola consultazione: si aggiornano con `git pull`, mai a mano.

## 2. Rami, pull request e tag

| Ramo o tag | Chi | Regola |
| --- | --- | --- |
| `main` | nessuno direttamente | Versione in produzione. Si aggiorna solo unendo una pull request approvata dall'utente. |
| `codex/<tema>-<AAAAMMGG>` | Codex | Lavoro di Codex. |
| `claude/<tema>-<AAAAMMGG>` | Claude | Lavoro di Claude. |
| tag `prod-<AAAAMMGG>` | chi rilascia | Messo sul commit di `main` rilasciato in produzione. È il punto di rollback e la versione da portare su DR. |
| tag `archivio/<nome>-<AAAAMMGG>` | chi chiude un ramo | Conserva la punta di un ramo che viene cancellato. |

Non si usano rami `production`: il loro ruolo è svolto da `main` più i tag `prod-…`.

## 3. Convivenza tra agenti

1. Un tema, un ramo, un agente. Prima di iniziare controllare che non ci siano rami aperti dell'altro agente
   sugli stessi file (`git ls-remote --heads origin` e il confronto con `main`).
2. Un agente non modifica né cancella il ramo dell'altro. Per riprendere un lavoro altrui si crea un ramo
   nuovo partendo da quello.
3. Prima di modificare `AGENTS.md`, `CLAUDE.md` o questo repository si apre una pull request; non si cambiano
   regole dentro un ramo di sviluppo funzionale.
4. I rami uniti in `main` si cancellano. I rami abbandonati si chiudono con un tag `archivio/…` se contengono
   lavoro da conservare.

## 4. Contenuto di ogni pull request

- Cosa cambia e perché.
- Test eseguiti in TEST, con esito; quelli non eseguiti, dichiarati come tali.
- Rischi, effetti su dati e integrazioni, piano di rollback.
- Prossimo passo strettamente necessario.

## 5. Segreti e dati

- `.env`, chiavi, token e password non vanno mai nei repository, nei log, nelle pull request o nelle copie su `X:`.
- Non cercare credenziali nei workspace e non mostrarle. La chiave SSH dedicata per il server TEST è indicata
  nell'`AGENTS.md` di ciascun progetto.
- Mai copiare dati TEST in PRODUZIONE.

## 6. Metodo di lavoro

Un obiettivo per volta, con un risultato concreto e verificabile. Prima riutilizzare, poi sviluppare.
Controlli proporzionati al rischio. Non riaprire decisioni già approvate senza un impedimento concreto e
documentato. Non aprire filoni collaterali: segnalare i problemi estranei all'obiettivo. Concludere ogni
incarico con risultato, test, impedimenti e prossimo passo.
