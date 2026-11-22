# Script di build e file di sistema: servono solo durante la build, non finiscono nell'immagine
FROM scratch AS ctx
COPY build_files /
COPY system_files /system_files
COPY cosign.pub /cosign.pub

# Base: Universal Blue base-main con la versione di Fedora fissata (si aggiorna a mano)
FROM ghcr.io/ublue-os/base-main:45

# Tutte le modifiche stanno in build_files/build.sh e in system_files/
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/build.sh

# Controllo finale dell'immagine
RUN bootc container lint
