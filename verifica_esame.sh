#!/usr/bin/env bash
#
# verifica_esame.sh
#
# Esplode un archivio tar contenente una directory per studente (nome = cognome),
# ciascuna con un sorgente C. Compila ogni sorgente e produce un report testuale
# con due elenchi ordinati alfabeticamente:
#   1) studenti il cui codice compila senza errori
#   2) studenti il cui codice presenta errori, con i messaggi del compilatore
#
# Uso: ./verifica_esame.sh archivio.tar [report.txt]

set -euo pipefail

ARCHIVIO="${1:?Uso: $0 archivio.tar [report.txt]}"
REPORT="${2:-report_compilazione.txt}"

if [[ ! -f "$ARCHIVIO" ]]; then
    echo "Errore: archivio '$ARCHIVIO' non trovato." >&2
    exit 1
fi

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT   # pulizia automatica anche in caso di errore

tar -xf "$ARCHIVIO" -C "$TMPDIR"

# array associativi: cognome -> esito (per poterli poi ordinare)
declare -A OK_STUDENTI
declare -A ERR_STUDENTI

for dir in "$TMPDIR"/*/; do
    [[ -d "$dir" ]] || continue
    studente=$(basename "$dir")

    # prendo il primo sorgente .c trovato nella directory dello studente
    sorgente=$(find "$dir" -maxdepth 1 -name '*.c' -print -quit)

    if [[ -z "$sorgente" ]]; then
        ERR_STUDENTI["$studente"]="Nessun file sorgente .c trovato nella directory."
        continue
    fi

    # -fsyntax-only: verifica la correttezza senza generare l'eseguibile
    if errori=$(gcc -fsyntax-only "$sorgente" 2>&1); then
        OK_STUDENTI["$studente"]=1
    else
        ERR_STUDENTI["$studente"]="$errori"
    fi
done

{
    echo "REPORT COMPILAZIONE ESAME"
    echo "Archivio: $ARCHIVIO"
    echo "Data: $(date '+%Y-%m-%d %H:%M')"
    echo "=========================================="
    echo
    echo "--- STUDENTI CON CODICE CORRETTO (${#OK_STUDENTI[@]}) ---"
    if [[ ${#OK_STUDENTI[@]} -eq 0 ]]; then
        echo "(nessuno)"
    else
        for s in $(printf '%s\n' "${!OK_STUDENTI[@]}" | sort); do
            echo "  - $s"
        done
    fi
    echo
    echo "--- STUDENTI CON ERRORI DI COMPILAZIONE (${#ERR_STUDENTI[@]}) ---"
    if [[ ${#ERR_STUDENTI[@]} -eq 0 ]]; then
        echo "(nessuno)"
    else
        for s in $(printf '%s\n' "${!ERR_STUDENTI[@]}" | sort); do
            echo "  - $s"
            echo "    ---- messaggi del compilatore ----"
            echo "${ERR_STUDENTI[$s]}" | sed 's/^/    /'
            echo
        done
    fi
} > "$REPORT"

echo "Report generato: $REPORT"
