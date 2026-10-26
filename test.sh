#!/usr/bin/env bash
#
# test.sh: prove automatiche per verifica_esame.sh
#
# Costruisce da sé gli archivi di prova in una cartella temporanea, lancia lo
# script e controlla il risultato. Non tocca i file del repository.
#
# Uso: ./test.sh        (oppure: bash test.sh)
# Esce con 0 se tutte le prove passano, con 1 se ne fallisce almeno una.

set -u

AQUI="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$AQUI/verifica_esame.sh"
BASH_BIN="$(command -v bash)"

[[ -f "$SCRIPT" ]] || { echo "Non trovo $SCRIPT" >&2; exit 2; }
command -v gcc >/dev/null 2>&1 || { echo "Serve gcc per eseguire le prove." >&2; exit 2; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# Le cartelle temporanee dello script finiscono qui dentro: così si può
# controllare che ne sparisca ogni traccia a lavoro finito.
export TMPDIR="$WORK/tmp"
mkdir -p "$TMPDIR"

ok=0
ko=0
check() {   # check "descrizione" "trovato" "atteso"
    if [[ "$2" == "$3" ]]; then
        printf '  OK    %s\n' "$1"; ok=$((ok + 1))
    else
        printf '  FAIL  %s\n          atteso: [%s]\n          trovato: [%s]\n' "$1" "$3" "$2"; ko=$((ko + 1))
    fi
}
conta() { grep -c -- "$1" "$2" || true; }                      # righe che contengono il testo
sezione() { sed -n "/$2/,/^--- /p" "$1" | grep '^  - ' | sed 's/^  - //'; }   # nomi elencati in una sezione
lancia() { "$BASH_BIN" "$SCRIPT" "$@" >/dev/null 2>&1; echo $?; }

CORRETTO='#include <stdio.h>
int main(void) { printf("ok\n"); return 0; }'
ERRATO='#include <stdio.h>
int main(void) { printf("ko\n") return 0; }'

nuovo() {   # nuovo NOME : crea una cartella vuota di prova
    rm -rf "$WORK/$1"; mkdir -p "$WORK/$1"; echo "$WORK/$1"
}
studente() {   # studente CARTELLA COGNOME FILE CODICE
    mkdir -p "$1/$2"; printf '%s\n' "$4" > "$1/$2/$3"
}
impacchetta() { tar -cf "$WORK/$1.tar" -C "$WORK/$1" .; }

echo "== 1. Archivio con casi limite =="
d=$(nuovo misto)
studente "$d" "Rossi"      main.c  "$CORRETTO"
studente "$d" "Bianchi"    main.c  "$ERRATO"
studente "$d" "De Luca"    main.c  "$CORRETTO"      # cognome con lo spazio
studente "$d" "Di Ciaula"  esame.c "$ERRATO"        # spazio e codice errato
studente "$d" "D'Amico"    main.c  "$CORRETTO"      # apostrofo
studente "$d" "Perù"       main.c  "$CORRETTO"      # lettera accentata
studente "$d" "DueFile"    a.c     "$CORRETTO"; printf '%s\n' "$CORRETTO" > "$d/DueFile/b.c"
mkdir -p "$d/Vuoto" "$d/__MACOSX"                   # cartella vuota e spazzatura di macOS
impacchetta misto
cd "$WORK" || exit 2
"$BASH_BIN" "$SCRIPT" misto.tar misto.txt >/dev/null 2>&1; rc=$?
check "esce con codice 0" "$rc" "0"
check "corretti: 4"           "$(conta 'CODICE CORRETTO (4)' misto.txt)" "1"
check "errori: 2"             "$(conta 'ERRORI DI COMPILAZIONE (2)' misto.txt)" "1"
check "ambigui: 2"            "$(conta 'REVISIONE MANUALE (2)' misto.txt)" "1"
check "«De Luca» resta intero" "$(conta '^  - De Luca$' misto.txt)" "1"
check "«Di Ciaula» resta intero" "$(conta '^  - Di Ciaula$' misto.txt)" "1"
check "nessun cognome spezzato (De, Luca, Di, Ciaula)" \
    "$(grep -cFx -e '  - De' -e '  - Luca' -e '  - Di' -e '  - Ciaula' misto.txt || true)" "0"
check "__MACOSX ignorato"     "$(conta '__MACOSX' misto.txt)" "0"
check "nessun percorso temporaneo nei messaggi" "$(conta "$WORK" misto.txt)" "0"
check "corretti in ordine alfabetico" "$(sezione misto.txt 'CODICE CORRETTO' | paste -sd,)" "D'Amico,De Luca,Perù,Rossi"
check "ambigui: DueFile e Vuoto"      "$(sezione misto.txt 'CASI AMBIGUI' | paste -sd,)" "DueFile,Vuoto"

echo "== 2. Nessuno ha errori (categoria vuota) =="
d=$(nuovo tuttiok)
studente "$d" "Alfa" x.c "$CORRETTO"
studente "$d" "Beta" y.c "$CORRETTO"
impacchetta tuttiok
check "esce con codice 0" "$(lancia tuttiok.tar tuttiok.txt)" "0"
check "errori: 0"  "$(conta 'ERRORI DI COMPILAZIONE (0)' tuttiok.txt)" "1"
check "ambigui: 0" "$(conta 'REVISIONE MANUALE (0)' tuttiok.txt)" "1"

echo "== 3. Nessuno compila (categoria vuota) =="
d=$(nuovo tuttiko)
studente "$d" "Alfa" x.c "$ERRATO"
impacchetta tuttiko
check "esce con codice 0" "$(lancia tuttiko.tar tuttiko.txt)" "0"
check "corretti: 0" "$(conta 'CODICE CORRETTO (0)' tuttiko.txt)" "1"
check "Alfa tra gli errori" "$(sezione tuttiko.txt 'ERRORI DI COMPILAZIONE' | head -1)" "Alfa"

echo "== 4. Archivio senza cartelle di studenti =="
d=$(nuovo vuoto); touch "$d/leggimi.txt"
impacchetta vuoto
check "esce con codice 0" "$(lancia vuoto.tar vuoto.txt)" "0"
check "tre categorie a zero" "$(conta '(0) ---' vuoto.txt)" "3"

echo "== 5. Uso sbagliato =="
check "senza argomenti: esce con errore" "$([[ $(lancia) -ne 0 ]] && echo si)" "si"
check "archivio inesistente: esce con errore" "$([[ $(lancia non_esiste.tar) -ne 0 ]] && echo si)" "si"

echo "== 6. gcc assente =="
mkdir -p "$WORK/senzagcc"
msg=$(PATH="$WORK/senzagcc" "$BASH_BIN" "$SCRIPT" misto.tar x.txt 2>&1); rc=$?
check "esce con errore" "$([[ $rc -ne 0 ]] && echo si)" "si"
check "il messaggio nomina gcc" "$(grep -c 'gcc' <<< "$msg")" "1"

echo "== 7. Pulizia =="
"$BASH_BIN" "$SCRIPT" misto.tar pulizia.txt >/dev/null 2>&1
check "nessuna cartella temporanea residua" "$(find "$TMPDIR" -mindepth 1 | wc -l | tr -d ' ')" "0"

echo "== 8. Archivio di esempio del repository =="
if [[ -f "$AQUI/esame_demo.tar" && -f "$AQUI/report_demo.txt" ]]; then
    "$BASH_BIN" "$SCRIPT" "$AQUI/esame_demo.tar" demo.txt >/dev/null 2>&1; rc=$?
    check "esce con codice 0" "$rc" "0"
    # Si saltano le prime tre righe: contengono titolo, percorso e data, che cambiano.
    diff <(sed 1,3d demo.txt) <(sed 1,3d "$AQUI/report_demo.txt") >/dev/null 2>&1
    check "il report coincide con report_demo.txt" "$([[ $? -eq 0 ]] && echo si)" "si"
else
    echo "  (saltata: esame_demo.tar o report_demo.txt non presenti)"
fi

echo
echo "Risultato: $ok prove superate, $ko fallite."
[[ $ko -eq 0 ]]
