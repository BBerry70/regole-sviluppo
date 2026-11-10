# Procedura standard di sviluppo, rilascio e disaster recovery

Versione 1.2 — 9 ottobre 2026

## Scopo
Applicare a CARMA, PRIST, SOFIA, Delivery Planner e alle altre applicazioni aziendali un ciclo uniforme: **TEST → approvazione → PRODUZIONE → DR**.

## Definizione di isolamento TEST
**TEST isolato non significa necessariamente TEST senza accesso ai dati reali. Significa TEST senza possibilità di modificarli.**

Sono consentite le letture dei sistemi aziendali esplicitamente autorizzate e tecnicamente verificate. La presenza di una connessione, da sola, non dimostra una violazione dell'isolamento. Devono essere impediti scritture, invii, automazioni e qualsiasi effetto operativo indesiderato verso PRODUZIONE, DR e sistemi aziendali.

Per ciascuna dipendenza autorizzata verificare:
- il percorso di codice effettivamente eseguito, le query e le API utilizzate, e l'assenza di operazioni di scrittura;
- le protezioni del client/driver e i privilegi dell'identità utilizzata, senza eseguire tentativi di scrittura sui sistemi reali;
- l'uso delle condivisioni esclusivamente in lettura, con protezioni filesystem compatibili;
- la destinazione dei database applicativi modificabili, che deve restare esclusivamente TEST;
- protezioni di rete compatibili con le sole destinazioni di lettura autorizzate. Una whitelist di rete limita le destinazioni ma non garantisce da sola la sola lettura.

**Autorizzazione specifica Delivery Planner, 8 ottobre 2026:** mantenere l'accesso ARCA aziendale se la verifica del percorso effettivo conferma la sola lettura e l'assenza di scritture. Verificare PostgreSQL TEST sulla porta 5433 e condivisioni aziendali in sola lettura; rendere il servizio TEST persistente con protezioni compatibili. Non eseguire quarantena né disabilitare ARCA per il solo fatto che esista la connessione.

Questa precisazione non autorizza invii, scritture o attivazione generalizzata di integrazioni. Restano valide le restrizioni specifiche delle singole applicazioni, incluse le protezioni CARMA, salvo istruzioni esplicite dell'utente.

## Regole inderogabili
1. Lo sviluppo ordinario avviene esclusivamente in TEST. Codex non modifica direttamente codice o configurazioni PRODUZIONE e DR.
2. Prima di ogni sincronizzazione salvare modifiche locali, configurazioni e stato attuale; non sovrascrivere `.env`, credenziali, dati o modifiche TEST non ancora integrate.
3. Separare per ambiente codice, file configurazione, database, porte, servizi systemd, directory scrivibili e integrazioni. Non dedurre che la separazione sia completa dai soli nomi dei file.
4. TEST: disabilitare scheduler, invii email, WhatsApp, webhook, automazioni, pagamenti, scritture ARCA/Vtiger e qualsiasi altra operazione con effetti reali, salvo integrazioni esplicitamente autorizzate e isolate.
5. I dati PRODUZIONE possono essere copiati in TEST soltanto con autorizzazione e modalità di lettura dalla produzione. Preservare i dati TEST esistenti con backup e gestione dei conflitti. Mai TEST → PRODUZIONE per dati applicativi.
6. Nessun rilascio in PRODUZIONE senza approvazione esplicita dell'utente, backup verificato, piano di rollback e controllo dei prerequisiti.
7. DR replica la versione **approvata e funzionante** in PRODUZIONE, non il codice in lavorazione TEST. DR non deve attivare automazioni o doppie scritture prima di un failover autorizzato.
8. Non mostrare né copiare nei log password, token, chiavi private o contenuti integrali dei file di configurazione. Non attivare sudo senza password per comodità.
9. Non usare comandi distruttivi, `rsync --delete`, migrazioni irreversibili o sostituzioni di database senza backup, verifica di impatto e autorizzazione quando necessaria.

## Flusso di lavoro Codex
### A. Preparazione TEST
- Verificare che l'applicazione TEST sia realmente isolata e accessibile.
- Identificare baseline codice, eventuali modifiche pendenti e dipendenze.
- Creare backup/riferimento di ripristino prima delle modifiche.

### B. Sviluppo
- Modificare soltanto TEST o un branch di sviluppo associato al TEST.
- Applicare eventuali migrazioni soltanto al database TEST.
- Eseguire test automatici, smoke test HTTP e verifica funzionale pertinente.
- Fornire un riepilogo sintetico: modifiche, test superati, limitazioni, rischi e file coinvolti.

### C. Approvazione
- Preparare pacchetto di rilascio riproducibile: commit/release, configurazioni richieste, migrazioni, ordine operazioni, verifiche e rollback.
- Richiedere autorizzazione esplicita per la distribuzione in PRODUZIONE.

### D. Rilascio PRODUZIONE
- Preflight: spazio, servizi, backup di codice e database, dipendenze, migrazioni, stato operativo.
- Distribuire esclusivamente quanto approvato, preservando segreti e configurazioni PRODUZIONE.
- Verificare health, login, funzioni critiche, log e processi schedulati.
- In caso di errore, fermare il rilascio e attivare rollback secondo il piano.

### E. Aggiornamento DR
- Solo dopo verifica PRODUZIONE: sincronizzare versione approvata e configurazioni compatibili, preservando impostazioni specifiche DR.
- Verificare replica database, servizi standby spenti/mascherati secondo architettura e capacità di failover.
- Non accendere servizi con effetti esterni sul DR.

## Registrazione minima per ogni rilascio
- Applicazione, versione/commit, data, autore, approvazione.
- Backup e percorso di rollback.
- Migrazioni e compatibilità database.
- Risultati dei test TEST e smoke test PRODUZIONE.
- Esito aggiornamento DR ed eventuali anomalie.

## Applicazioni e stato iniziale (da verificare sul server)
| Applicazione | TEST | DR | Prossima azione |
|---|---|---|---|
| CARMA | Attivo: `192.168.1.20:18000`, PG 5433 `acrm` | Copia su standby | Consolidare pipeline di rilascio |
| Delivery Planner | Test già predisposto su porta 18022 | Copia su standby | Verificare servizio persistente, isolamento e baseline |
| SOFIA | Test predisposto su porta 18020, precedentemente fermato | Copia su standby | Verificare stato e riattivazione sicura |
| PRIST | Da attivare | Copia su standby | Priorità immediata |
| WhatsApp webhook | Da verificare/attivare | Copia su standby | Isolare credenziali, webhook e invii |
| Mautic webhook | Da verificare/attivare | Copia su standby | Isolare callback e scritture |
| Altri servizi, tracking, procedure | Da censire | Da verificare | Inventario e piano progressivo |

Le porte e i percorsi sono riferimenti di lavoro, non sostituiscono la verifica tecnica effettiva.

## Istruzione permanente per Codex
«Opera in TEST per ogni modifica; automatizza i controlli non distruttivi; non interromperti per conferme intermedie. Richiedi approvazione soltanto per rilasci PRODUZIONE, operazioni distruttive, accessi a dati reali non già autorizzati e modifiche alla sicurezza. Mantieni PRODUZIONE e DR immutati durante lo sviluppo. Comunica sempre risultato, test e prossimo passo concreto.»


## Requisito CARMA TEST funzionale — 9 ottobre 2026
Questa disposizione sostituisce il precedente blocco generalizzato delle letture ARCA/Vtiger per CARMA. TEST deve offrire consultazione clienti, ordini, fatture, listini, KPI, analisi e preventivi, con dati aziendali reali leggibili quando i privilegi e il percorso effettivo sono verificati. L'isolamento impedisce effetti indesiderati sulla produzione, non le letture necessarie al funzionamento.

- ARCA SQL Server: solo 192.168.1.98:1433, ADB_DOPPINCOLLA, con account i cui privilegi effettivi (inclusi public, ruoli e procedure) consentano soltanto letture. La sola assenza di INSERT/UPDATE/DELETE sulle tabelle non certifica la sola lettura se sono eseguibili procedure con effetti non verificati.
- Vtiger MySQL: solo 192.168.1.99:3306, vt75, account SELECT autorizzato dall'host TEST 192.168.1.20; nessun EXECUTE, scrittura, GRANT OPTION o ruolo non verificato.
- PostgreSQL modificabile: esclusivamente 127.0.0.1:5433/acrm. Commenti, attività, preventivi e altri dati applicativi del TEST devono restare nel TEST; mai trasferire questi dati in PRODUZIONE.
- Le protezioni devono agire a più livelli: privilegi dei database esterni, SELECT/CTE soltanto nei client, connessioni read-only, egress limitato alle destinazioni/porte autorizzate, filesystem confinato. Anche Orderanalysis e gli altri percorsi secondari devono usare lo stesso confine verificato.
- Restano impediti invii email/WhatsApp, scritture esterne e chiamate operative non autorizzate. Predisporre simulazioni consultabili in TEST senza invio reale; nessun invio deve essere mascherato come simulazione.
- Non cambiare account, configurazioni o permessi PRODUZIONE/DR per comodità. Se mancano account idonei o autorizzazione dall'host TEST, segnalare il blocco prima dell'attivazione e preparare istruzioni amministrative per un account dedicato, senza modificare gli account di produzione.
- Il collaudo deve verificare le API e i dati delle principali schermate; HTML 200 e /health 200 da soli non costituiscono ripristino funzionale. Riportare separatamente risultati sul candidato TEST e sul servizio effettivamente attivo.
