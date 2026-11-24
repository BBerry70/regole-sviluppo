# Script privilegiati comuni a tutti i progetti

Copie approvate degli script che l'utente `claude` può eseguire con sudo senza password (deroga D1,
`CLAUDE_CODE_SERVER_TEST.md` §6.2). Installati come `root:root 0755` in `/usr/local/sbin/`, non
modificabili da `claude`. Si lanciano da `ops/` di questo repository.

| Script | Cosa fa |
| --- | --- |
| `backup-sfoltisci` | Cancella i backup vecchi in `/opt/acrm/backups`, `/opt/test/acrm/backups`, `/opt/delivery-planner/backups`, `/opt/test/delivery-planner/backups` (quelle presenti sul server). Tocca solo: **backup dei rilasci** `claude-<ambiente>-AAAAMMGG-HHMMSS/` (tiene i 3 più recenti per ambiente e quello citato da `claude-<ambiente>-ultimo`, usato dal rollback) e **dump giornalieri** `acrm_dev_before_refresh_*.dump` (tiene i 14 più recenti e il primo di ciascuno degli ultimi 6 mesi). Dump fatti a mano, `deploy_*`, backup PRIST e ogni altra voce restano. Senza argomenti cancella; `--prova` elenca soltanto. Lancio: `ops/backup-sfoltisci.sh <test\|prod> [--prova]`; in automatico ogni domenica alle 04:30 con `backup-sfoltisci.timer` |

## Installazione

Sul server TEST/DR (dall'utente `andrea` su 192.168.1.20, dopo il merge, con il clone su `main`):

```bash
R=/home/claude/lavoro/regole-sviluppo/ops; sudo visudo -cf $R/preparazione/claude-ops.sudoers && sudo install -o root -g root -m 0755 $R/sbin/backup-sfoltisci /usr/local/sbin/backup-sfoltisci && sudo install -o root -g root -m 0644 $R/preparazione/backup-sfoltisci.service $R/preparazione/backup-sfoltisci.timer /etc/systemd/system/ && sudo install -o root -g root -m 0440 $R/preparazione/claude-ops.sudoers /etc/sudoers.d/claude-ops && sudo systemctl daemon-reload && sudo systemctl enable --now backup-sfoltisci.timer && sudo -l -U claude | grep backup
```

Sul server di PRODUZIONE (dall'utente `andrea` su 192.168.1.20, due comandi):

```bash
sudo tar -cf - -C /home/claude/lavoro/regole-sviluppo/ops sbin/backup-sfoltisci preparazione/backup-sfoltisci.service preparazione/backup-sfoltisci.timer preparazione/claude-ops-prod.sudoers | ssh andrea@192.168.1.126 "rm -rf /tmp/claude-ops-inst && mkdir /tmp/claude-ops-inst && tar -x -C /tmp/claude-ops-inst"
ssh -t andrea@192.168.1.126 "cd /tmp/claude-ops-inst && sudo visudo -cf preparazione/claude-ops-prod.sudoers && sudo install -o root -g root -m 0755 sbin/backup-sfoltisci /usr/local/sbin/backup-sfoltisci && sudo install -o root -g root -m 0644 preparazione/backup-sfoltisci.service preparazione/backup-sfoltisci.timer /etc/systemd/system/ && sudo install -o root -g root -m 0440 preparazione/claude-ops-prod.sudoers /etc/sudoers.d/claude-ops && sudo systemctl daemon-reload && sudo systemctl enable --now backup-sfoltisci.timer && sudo -l -U claude | grep backup; rm -rf /tmp/claude-ops-inst"
```

Il timer non cancella nulla all'installazione: la prima esecuzione automatica è la domenica successiva.
Prima pulizia, se voluta subito: `ops/backup-sfoltisci.sh <test|prod> --prova`, poi senza `--prova`.
Il log delle esecuzioni automatiche: `journalctl -u backup-sfoltisci.service`.
