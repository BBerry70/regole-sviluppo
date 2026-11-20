#!/usr/bin/env python3
"""Confronta i file di un riferimento git (tag, ramo, commit) con una cartella installata.

Solo lettura. La cartella può essere locale o su un host remoto raggiunto via ssh.
Uso:
  confronta.py --repo DIR --ref prod-20261120 --dir /opt/acrm/app [--ssh utente@host]
               [--prefisso src/] [--escludi doc/ --escludi tests/] [--elenco 20]

Esito: 0 se tutti i file presenti in entrambi coincidono, 1 se ci sono differenze, 2 per errore.
I file del riferimento assenti nella cartella sono contati a parte (spesso documentazione non installata).
Il contenuto dei file non viene mai stampato, solo i percorsi.
"""
import argparse
import hashlib
import subprocess
import sys


def blob_del_riferimento(repo, ref, escludi):
    out = subprocess.run(
        ["git", "-C", repo, "ls-tree", "-r", "-z", ref],
        check=True, capture_output=True,
    ).stdout
    voci = {}
    for riga in out.split(b"\0"):
        if not riga:
            continue
        meta, percorso = riga.split(b"\t", 1)
        modo, tipo, oid = meta.split()
        p = percorso.decode()
        if tipo != b"blob" or modo == b"120000":
            continue
        if any(p.startswith(e) for e in escludi):
            continue
        voci[p] = oid.decode()
    # sha256 dei blob con un solo processo git cat-file --batch
    proc = subprocess.Popen(
        ["git", "-C", repo, "cat-file", "--batch"],
        stdin=subprocess.PIPE, stdout=subprocess.PIPE,
    )
    hash_attesi = {}
    for p, oid in voci.items():
        proc.stdin.write(oid.encode() + b"\n")
        proc.stdin.flush()
        intestazione = proc.stdout.readline().split()
        dim = int(intestazione[2])
        dati = proc.stdout.read(dim)
        proc.stdout.read(1)
        hash_attesi[p] = hashlib.sha256(dati).hexdigest()
    proc.stdin.close()
    proc.wait()
    return hash_attesi


def hash_installati(cartella, percorsi, ssh):
    # sha256sum sui soli file esistenti; i nomi passano su stdin separati da NUL.
    script = (
        "cd -- \"$1\" || exit 2; "
        "while IFS= read -r -d '' f; do [ -f \"$f\" ] && [ -r \"$f\" ] && printf '%s\\0' \"$f\"; done "
        "| xargs -0 -r sha256sum --"
    )
    comando = ["bash", "-c", script, "confronta", cartella]
    if ssh:
        import shlex
        comando = ["ssh", "-o", "BatchMode=yes", "-o", "ConnectTimeout=10", ssh,
                   " ".join(shlex.quote(c) for c in comando)]
    ingresso = b"".join(p.encode() + b"\0" for p in percorsi)
    r = subprocess.run(comando, input=ingresso, capture_output=True)
    if r.returncode not in (0, 123):
        sys.stderr.write(r.stderr.decode(errors="replace"))
        raise SystemExit(2)
    trovati = {}
    for riga in r.stdout.decode(errors="replace").splitlines():
        h, _, p = riga.partition("  ")
        trovati[p] = h
    return trovati


def main():
    a = argparse.ArgumentParser()
    a.add_argument("--repo", required=True)
    a.add_argument("--ref", required=True)
    a.add_argument("--dir", required=True)
    a.add_argument("--ssh")
    a.add_argument("--escludi", action="append", default=[])
    a.add_argument("--elenco", type=int, default=20)
    a.add_argument("--etichetta", default="")
    x = a.parse_args()

    attesi = blob_del_riferimento(x.repo, x.ref, x.escludi)
    installati = hash_installati(x.dir, list(attesi), x.ssh)
    diversi = sorted(p for p, h in installati.items() if attesi.get(p) != h)
    mancanti = sorted(p for p in attesi if p not in installati)
    uguali = len(installati) - len(diversi)

    etichetta = x.etichetta or x.dir
    print(f"{etichetta}: confronto con {x.ref}: {uguali} uguali, {len(diversi)} diversi, "
          f"{len(mancanti)} assenti nella cartella")
    for p in diversi[: x.elenco]:
        print(f"  diverso: {p}")
    if len(diversi) > x.elenco:
        print(f"  … altri {len(diversi) - x.elenco} file diversi")
    return 1 if diversi else 0


if __name__ == "__main__":
    sys.exit(main())
