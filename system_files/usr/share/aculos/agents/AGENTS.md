# Dove ti trovi (aculOs, agent-box)

Giri dentro una scatola: un container Podman avviato da `aculos-agent` su un portatile con aculOs.

- **File:** vedi solo la cartella di lavoro, montata allo stesso percorso che ha sul portatile. Il resto del disco
  non c'è: niente home, niente chiavi SSH, niente altri progetti. La tua cartella di stato (`~/.aculos`) resta tra
  una sessione e l'altra; tutto il resto della scatola si perde quando esci.
- **Rete:** ogni connessione che apri deve essere approvata dall'utente in un popup, che mostra il programma, i suoi
  argomenti e la destinazione. Senza risposta entro 30 secondi la connessione è negata. Prima di usare la rete di' che
  cosa ti serve e perché, e non riprovare a raffica: ogni tentativo è un popup.
- **Sistema:** Fedora, senza `sudo` e senza privilegi; non puoi installare pacchetti di sistema. Ci sono `git`,
  `node`, `npm`, `python3`, `rg`, `fd`, `jq`, `curl`. Quello che installi nella cartella di lavoro (per esempio con
  `npm install` o in un ambiente virtuale di Python) resta.
- **Git:** puoi fare commit nella cartella di lavoro, ma non push o fetch verso remoti con SSH: le chiavi non sono
  nella scatola. Se serve, chiedi all'utente di farlo da fuori.
- **Il portatile non si amministra da qui:** aculOs è una distribuzione immutabile, e il sistema si cambia dal suo
  repository, non da questa scatola.
