# Comandi da consegnare all'utente (postazione Windows)

Versione 1.0 — 10 novembre 2026. Vale per tutti i progetti e per tutti gli agenti (Codex, Claude Code)
ogni volta che un comando deve essere eseguito dall'utente sul proprio PC.

## 1. Ambiente dell'utente

- Sistema: Windows, **Windows PowerShell 5.1**.
- Cartelle di lavoro: `C:\Progetticlaude\<progetto>` (es. `C:\Progetticlaude\CARMA`).
- Accesso ai server con `ssh` di OpenSSH per Windows.

Ogni comando va scritto per questo ambiente, non per una shell Linux.

## 2. Regole

1. **Niente `<` per l'input.** In PowerShell `<` non è supportato ("Operatore '<' riservato per utilizzi
   futuri"). Per passare un file a un comando usare `Get-Content -Raw file | comando`.
2. **Percorsi locali con `$env:USERPROFILE`**, non con `~`, e sempre tra virgolette.
3. **Script inviati ai server Linux via ssh:**
   - solo caratteri ASCII;
   - togliere i ritorni a capo Windows con `-replace "`r",""`;
   - terminare lo script con `exit 0` come ultima riga: PowerShell 5.1 aggiunge un CRLF in coda alla pipe
     verso i programmi esterni e bash lo eseguirebbe come comando (`$'\r': command not found`).
4. **Output su file locale** con `Out-File -Encoding utf8`, non con `>`, così il file resta leggibile.
5. **Prima di consegnare un comando**, verificare come lo interpreta la shell di partenza (PowerShell) e non
   solo la shell del server.
6. **Un comando per blocco**, pronto da copiare, senza prompt iniziale e senza output mescolato.
7. Nessun comando deve stampare o salvare password, chiavi, token o DSN.
8. **Non presumere strumenti o copie git sul PC.** `C:\Progetticlaude\<progetto>` non è una copia
   git del repository. Il codice da portare su un server si consegna come pacchetto già pronto
   (`.tar.gz`, solo le cartelle necessarie, senza immagini o dati non utili), con la sua impronta
   SHA256 da verificare prima dell'invio:
   `(Get-FileHash .\pacchetto.tar.gz -Algorithm SHA256).Hash`.
   La copia sul server si fa con `scp`; il server non scarica nulla da GitHub.
9. **Niente virgolette doppie dentro il comando remoto di `ssh`.** PowerShell 5.1 toglie le virgolette
   doppie interne agli argomenti dei programmi esterni: `ssh host 'grep -E ":1|:2"'` arriva al server come
   `grep -E :1|:2` e bash interpreta `|` come pipe. Il comando remoto tra apici singoli deve contenere solo
   parole semplici; filtri con spazi, `|`, `;` tra virgolette o espressioni regolari vanno in uno script
   inviato con la pipe del §3 (anche per i controlli veloci).
10. **Dire sempre da quale prompt si lancia il comando.** I comandi con `Get-Content`, `Out-File`, `scp` verso
   il server si lanciano da PowerShell sul PC (prompt `PS C:\PROGETTIClaude\<progetto>>`), mai dentro una
   sessione ssh aperta sul server (prompt `andrea@...:~$`): bash risponde `syntax error near unexpected token
   '-replace'`. Se il prompt è quello del server, prima `exit`.

## 3. Modello per eseguire uno script di sola lettura su un server

```powershell
(Get-Content -Raw .\script.sh) -replace "`r","" | ssh -i "$env:USERPROFILE\.ssh\<chiave>" andrea@<host> 'bash -s' | Out-File -Encoding utf8 .\risultato.txt
```

Lo script (`script.sh`) termina con:

```bash
# Uscita esplicita: ignora eventuali righe aggiunte dalla pipe di PowerShell (CRLF finale).
exit 0
```

Lo script non crea file sul server: il risultato arriva solo sul PC dell'utente.

## 4. Registro degli errori

Ogni errore causato da un comando consegnato all'utente va aggiunto qui con una pull request, insieme alla
regola che lo evita, così non si ripete.

| Data | Errore | Causa | Regola |
| --- | --- | --- | --- |
| 10/11/2026 | `Operatore '<' riservato per utilizzi futuri` | Redirezione `<` non supportata da PowerShell | §2.1 |
| 10/11/2026 | `bash: line N: $'\r': command not found` (N = righe dello script + 1) | PowerShell 5.1 aggiunge CRLF in coda alla pipe verso `ssh` | §2.3 |
| 10/11/2026 | `fatal: not a git repository` su `git fetch` | Presunta una copia git del progetto sul PC dell'utente | §2.8 |
| 11/11/2026 | `bash: line 1: :5433: command not found` e `grep` che mostra tutti i processi | PowerShell 5.1 toglie le virgolette doppie dentro il comando remoto di `ssh` | §2.9 |
| 11/11/2026 | `-bash: syntax error near unexpected token '-replace'` | Comando PowerShell lanciato dentro una sessione ssh sul server | §2.10 |
