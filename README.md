# Omarchy edge packages — RSS and Quickshell widget

Feed pubblico dei pacchetti nuovi o aggiornati in `core`, `extra`, `multilib` e `omarchy` (edge), più un widget Quickshell per Omarchy.

## Feed

Una GitHub Action controlla ogni ora i database pacman pubblici e conserva online uno snapshot di nomi e versioni. Alla prima esecuzione crea la baseline senza segnalare come nuovi i pacchetti che sono già presenti; i successivi inserimenti e cambi di versione diventano voci RSS. Lo storico pubblicato conserva gli ultimi 100 eventi.

Il feed viene pubblicato su GitHub Pages all'indirizzo:

`https://neuromante.github.io/omarchy-edge-packages/feed.xml`

Il controllo e l'elaborazione avvengono sui runner GitHub. Sul PC che usa il widget viene richiesta soltanto la risposta RSS, senza scaricare i database pacman e senza salvare la lista localmente.

## Widget Omarchy

Il repository è direttamente installabile come plugin Omarchy. La barra mostra un'icona RSS con il numero di eventi recenti; cliccandola si apre l'elenco. Nel pannello si può scegliere se mostrare gli ultimi 10, 50 o 100 eventi.

Installazione dopo la pubblicazione del repository:

```bash
omarchy plugin add https://github.com/neuromante/omarchy-edge-packages --enable
```

## Sviluppo e test

```bash
python -m pip install -r requirements.txt
python -m unittest discover -s tests
```

La pubblicazione automatica richiede le autorizzazioni `contents: write`, `pages: write` e `id-token: write`, già dichiarate nel workflow. La prima esecuzione programmata crea lo snapshot iniziale e pubblica il feed vuoto; da quel momento registra i nuovi arrivi e gli aggiornamenti.
