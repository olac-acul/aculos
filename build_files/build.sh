#!/bin/bash
# Build di aculOs: gira dentro il Containerfile, sopra base-main.
# Regola per i repo esterni (Terra, LibreWolf...): abilitarli solo per i pacchetti che servono, poi disattivarli.

set -ouex pipefail

# File di sistema del repo (system_files/) copiati in /
cp -avf "/ctx/system_files"/. /

### Pacchetti
# Fase 1: nessun pacchetto aggiunto, l'immagine è base-main così com'è.
# Dalla fase 2: niri, Noctalia, greetd...
