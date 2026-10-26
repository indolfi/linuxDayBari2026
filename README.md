# linuxDayBari2026
Contributo al Linux Day Bari 24 ottobre 2026
## verifica_esame

Uno script bash che corregge in batch le consegne di un esame di programmazione in C.

Partendo da un archivio `tar` con una cartella per studente, prova a compilare il sorgente di ciascuno con `gcc` e produce un report di testo con tre elenchi in ordine alfabetico: chi compila senza errori, chi ha errori (con i messaggi del compilatore per intero) e i casi che lo script non può decidere da solo.

Nasce come demo del talk **«Bash, non lo fare tanto vasce»** (Linux Day Bari 2026). Il filo del talk, con le storie e le fonti, è nell'articolo [L'osso e il satellite](https://pierangeloindolfi.substack.com/p/losso-e-il-satellite), su *Errori di sistema*.

## Uso

```
./verifica_esame.sh ARCHIVIO.tar [REPORT.txt]
```

Il report è facoltativo: se lo ometti, lo script scrive in `report_compilazione.txt` nella cartella corrente. Se il file esiste già, viene sovrascritto senza chiedere.

Per provarlo subito con l'archivio di esempio:

```
chmod +x verifica_esame.sh
./verifica_esame.sh esame_demo.tar report.txt
cat report.txt
```

Il `chmod` serve se il permesso di esecuzione è andato perso (succede quando si scarica il file da certi servizi). In alternativa: `bash verifica_esame.sh esame_demo.tar report.txt`.

## Cosa si aspetta in ingresso

Un archivio `tar` fatto così: una cartella per studente, con il cognome come nome, e dentro il sorgente C.

```
esame_demo.tar
├── Colella/
│   └── main.c
├── De Luca/
│   └── main.c
└── Perù/
    └── main.c
```

Lo script cerca i file `*.c` nel primo livello di ogni cartella. Il nome del file non importa.

## Cosa produce

```
REPORT COMPILAZIONE ESAME
Archivio: esame_demo.tar
Data: 2026-10-23 08:22
==========================================

--- CODICE CORRETTO (5) ---
  - Colella
  - D'Amico
  - De Palma
  - Lo Russo
  - Rossi

--- ERRORI DI COMPILAZIONE (3) ---
  - De Luca
      De Luca/main.c: In function ‘main’:
      De Luca/main.c:5:5: error: expected ‘,’ or ‘;’ before ‘int’
          5 |     int b = 3;
            |     ^~~
  ...

--- CASI AMBIGUI, REVISIONE MANUALE (2) ---
  - Gentile
      Più sorgenti .c, serve una revisione manuale:
        - main.c
        - main_old.c

  - Mastrolonardo
      Nessun file sorgente .c trovato.
```

Il report completo di questo esempio è in `report_demo.txt`.

## Come funziona

1. Estrae l'archivio in una cartella temporanea, che viene cancellata a fine lavoro anche se qualcosa va storto.
2. Per ogni cartella raccoglie i sorgenti `.c`. Nessuno o più di uno: lo studente va tra i casi ambigui, perché scegliere a caso sarebbe peggio che chiedere una revisione.
3. Con un solo sorgente lancia `gcc -fsyntax-only`, che controlla il codice senza produrre l'eseguibile. Le segnalazioni di gcc sono quelle che compaiono nel report.
4. Scrive i tre elenchi, ordinati alfabeticamente senza distinguere maiuscole e minuscole.

Qualche scelta voluta:

- `set -euo pipefail`: al primo errore lo script si ferma, invece di andare avanti con dati sporchi.
- L'ordinamento usa il locale `C.UTF-8`, così non cambia da una macchina all'altra (vedi il limite nella sezione successiva).
- Cognomi con spazi, apostrofi e lettere accentate funzionano (De Luca, D'Amico, Perù).
- Le cartelle spurie `__MACOSX`, tipiche degli archivi creati su macOS, vengono ignorate.

## Cosa non fa

- Non esegue i programmi e non ne controlla il risultato: dice se compilano, non se sono giusti.
- Non controlla l'originalità degli elaborati.
- Non cerca sorgenti nelle sottocartelle: un `src/main.c` finisce tra i casi ambigui come «nessun sorgente».
- Ordina per codice dei caratteri, senza distinguere maiuscole e minuscole: un cognome che *inizia* con una lettera accentata (Èvola) finisce dopo la Z. Le accentate dentro il cognome (Perù) non danno problemi.
- `-fsyntax-only` non esegue il collegamento: un `main` mancante o un riferimento a una funzione definita altrove non vengono segnalati come errori di compilazione.

## Requisiti

- Linux, con bash 4 o successivo (il bash 3.2 di macOS non va: lo script lo riconosce e si ferma con un messaggio)
- `gcc`
- `tar`, `find`, `sort`, `sed` (quelli di una distribuzione Linux normale)

Provato su Ubuntu 24.04 con bash 5.2 e gcc 13.

## Test

```
./test.sh
```

Lo script `test.sh` costruisce da sé gli archivi di prova in una cartella temporanea e controlla, tra le altre cose:

- cognomi con lo spazio, con l'apostrofo e con le lettere accentate;
- cartelle vuote, cartelle con due sorgenti e cartelle `__MACOSX`;
- categorie vuote (nessun errore, oppure nessuno che compila) e archivio senza studenti;
- argomenti sbagliati, `gcc` assente, pulizia della cartella temporanea;
- il confronto del report con `report_demo.txt`.

Prima di modificare lo script conviene lanciarlo: i primi due difetti trovati provandolo (i cognomi con lo spazio e le categorie vuote) ci sono finiti dentro come prove.

## Privacy

L'archivio `esame_demo.tar` contiene studenti inventati. Con elaborati veri vale la solita cautela: non mettere nel repository gli archivi degli esami né i report generati (vedi `.gitignore`).

## Autore

Pierangelo Indolfi

