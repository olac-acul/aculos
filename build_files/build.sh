#!/bin/bash
# Build di aculOs: gira dentro il Containerfile, sopra base-main.
# Regola per i repo esterni (Terra, LibreWolf...): abilitarli solo per i pacchetti che servono, poi disattivarli.

set -ouex pipefail

### Pacchetti di Fedora
# Fase 2: base del desktop (niri, greeter, portali, portachiavi, terminale, Tailscale)
dnf5 -y install \
    niri \
    xwayland-satellite \
    greetd \
    greetd-selinux \
    xdg-desktop-portal-gnome \
    xdg-desktop-portal-gtk \
    gnome-keyring \
    gnome-keyring-pam \
    accountsservice \
    polkit \
    kitty \
    tailscale

### Pacchetti di Terra (Noctalia)
# terra-release porta il file del repo e la chiave GPG; il repo resta installato ma spento,
# e si accende solo per i pacchetti che servono.
dnf5 -y install --nogpgcheck --repofrompath 'terra,https://repos.fyralabs.com/terra$releasever' terra-release
dnf5 config-manager setopt terra.enabled=0
dnf5 -y install --enablerepo=terra \
    noctalia-nightly \
    noctalia-greeter

### File di sistema del repo (system_files/) copiati in /, dopo i pacchetti così prevalgono sui loro default
cp -avf "/ctx/system_files"/. /

### Noctalia come servizio utente legato alla sessione di niri
# Il servizio è quello fornito da Noctalia, con il WantedBy per niri attivato.
sed 's/^# WantedBy=niri.service$/WantedBy=niri.service/' \
    /usr/share/noctalia/assets/noctalia.service > /usr/lib/systemd/user/noctalia.service
grep -q '^WantedBy=niri.service$' /usr/lib/systemd/user/noctalia.service
systemctl --global enable noctalia.service

### Configurazione predefinita di niri
mkdir -p /etc/niri
ln -sf /usr/share/aculos/niri/config.kdl /etc/niri/config.kdl

### Servizi di sistema
systemctl enable greetd.service
systemctl enable aculos-greeter-setup.service
systemctl enable tailscaled.service
systemctl set-default graphical.target
# Il login grafico è greetd su tty1: niente getty sullo stesso terminale
systemctl disable getty@tty1.service || true

### Versioni dei componenti principali, per sapere quale build si sta usando
mkdir -p /usr/share/aculos
rpm -q --qf '%{NAME} %{VERSION}-%{RELEASE}\n' \
    noctalia-nightly noctalia-greeter niri greetd kitty tailscale > /usr/share/aculos/versioni.txt
cat /usr/share/aculos/versioni.txt
