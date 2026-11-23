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

# Fase 3: portatile. tuned-ppd al posto di power-profiles-daemon (stessa interfaccia D-Bus, che Noctalia usa);
# intel-lpmd e thermald sono già nella base.
dnf5 -y swap power-profiles-daemon tuned-ppd
dnf5 -y install \
    fprintd \
    fprintd-pam

# Fase 5: comandi usati dai plugin di Noctalia (udiskie per le chiavette USB)
dnf5 -y install udiskie

# Fase 4: Syncthing e le app di sistema (file manager con anteprime, editor da terminale, appunti, tema GTK3)
dnf5 -y install \
    syncthing \
    nautilus \
    gvfs \
    ffmpegthumbnailer \
    micro \
    wl-clipboard \
    adw-gtk3-theme

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

### Impronta digitale: il modo standard di Fedora (authselect), con due eccezioni
# L'impronta vale per tutto ciò che usa system-auth (sudo, su, polkit). Il greeter e il servizio PAM "login"
# (la password del blocco schermo di Noctalia) usano invece password-auth, che authselect lascia senza
# pam_fprintd: al greeter serve la password per sbloccare il portachiavi, e il blocco schermo chiede
# l'impronta per conto suo direttamente a fprintd.
authselect enable-feature with-fingerprint
grep -q pam_fprintd /etc/authselect/system-auth
if grep -q pam_fprintd /etc/authselect/password-auth; then echo "pam_fprintd in password-auth" >&2; exit 1; fi
sed -E 's/^(auth[[:space:]]+substack[[:space:]]+)system-auth$/\1password-auth/' \
    /usr/lib/pam.d/greetd > /etc/pam.d/greetd
sed -i -E 's/^(auth[[:space:]]+substack[[:space:]]+)system-auth$/\1password-auth/' /etc/pam.d/login
grep -q -E '^auth[[:space:]]+substack[[:space:]]+password-auth$' /etc/pam.d/greetd
grep -q -E '^auth[[:space:]]+substack[[:space:]]+password-auth$' /etc/pam.d/login

### Firma: bootc accetta aculOs solo se firmata con la chiave del repo (cosign.pub)
# Stessa regola che la base usa per le immagini di Universal Blue. Dopo l'installazione (che scarica
# l'immagine senza verificarla) il kickstart passa a questa con bootc switch --enforce-container-sigpolicy.
install -D -m 644 /ctx/cosign.pub /etc/pki/containers/aculos.pub
python3 -I - <<'FINE'
import json
p = "/etc/containers/policy.json"
with open(p) as f:
    politica = json.load(f)
politica["transports"]["docker"]["ghcr.io/olac-acul/aculos"] = [{
    "type": "sigstoreSigned",
    "keyPath": "/etc/pki/containers/aculos.pub",
    "signedIdentity": {"type": "matchRepository"},
}]
with open(p, "w") as f:
    json.dump(politica, f, indent=4)
    f.write("\n")
FINE
grep -q '"ghcr.io/olac-acul/aculos"' /etc/containers/policy.json

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
systemctl enable tuned.service tuned-ppd.service
systemctl enable aculos-impronta-coperchio.service
# Servizi utente: partono solo se l'utente ha la loro configurazione in ~/.config/aculos (vedi le unità)
systemctl --global enable syncthing.service aculos-ntfy.service aculos-receive.service
systemctl set-default graphical.target
# Il login grafico è greetd su tty1: niente getty sullo stesso terminale
systemctl disable getty@tty1.service || true

### Versioni dei componenti principali, per sapere quale build si sta usando
mkdir -p /usr/share/aculos
rpm -q --qf '%{NAME} %{VERSION}-%{RELEASE}\n' \
    noctalia-nightly noctalia-greeter niri greetd kitty tailscale fprintd tuned-ppd syncthing > /usr/share/aculos/versioni.txt
cat /usr/share/aculos/versioni.txt

### Pulizia: niente resti in /run e /var (bootc container lint)
# /var/lib/noctalia-greeter lo riempie il %post del pacchetto durante la build: si svuota, così lo prepara
# aculos-greeter-setup.service al primo avvio, sul sistema vero.
rm -rf /run/dnf /run/selinux-policy /run/tuned /var/lib/dnf /var/lib/noctalia-greeter
