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
# niri porta con sé, come dipendenze consigliate, i programmi della sua configurazione di esempio. In aculOs li
# sostituiscono kitty (terminale) e Noctalia (barra, launcher, blocco schermo): via, così non compaiono nel menu.
dnf5 -y remove alacritty fuzzel swaylock waybar

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

# Fase 5: shell, strumenti da terminale, browser
dnf5 -y install \
    zsh zsh-autosuggestions zsh-syntax-highlighting \
    eza bat ripgrep fd-find fzf jq btop duf plocate \
    rsync pv socat wget2-wget unzip 7zip unrar snapper \
    chezmoi nodejs nodejs-npm \
    igt-gpu-tools ethtool \
    flatpak distrobox podman podman-compose \
    firefox chromium

# Fase 5: schermi esterni. kanshi riapplica la disposizione salvata per ogni combinazione di schermi (i profili
# li scrive aculos-display), wl-mirror duplica uno schermo su un altro, wlr-randr serve per le diagnosi.
dnf5 -y install kanshi wl-mirror wlr-randr

# Fase 5: per i temi alternativi del desktop: font a celle Terminus in TrueType (famiglia "Terminus (TTF)")
# e le icone Papirus (le cartelle colorate le ricava il comando dei temi, per l'utente)
dnf5 -y install ax86-terminus-ttf-fonts papirus-icon-theme papirus-icon-theme-dark

### Pacchetti di Terra (Noctalia)
# terra-release porta il file del repo e la chiave GPG; il repo resta installato ma spento,
# e si accende solo per i pacchetti che servono.
dnf5 -y install --nogpgcheck --repofrompath 'terra,https://repos.fyralabs.com/terra$releasever' terra-release
dnf5 config-manager setopt terra.enabled=0
dnf5 -y install --enablerepo=terra \
    noctalia-nightly \
    noctalia-greeter

# Fase 5, sempre da Terra: prompt, bw per chezmoi, mise per provare strumenti in user space, VSCodium
dnf5 -y install --enablerepo=terra \
    starship \
    bitwarden-cli \
    mise \
    codium

### LibreWolf dal suo repo ufficiale (installato ma spento, come Terra)
curl -fsSL https://repo.librewolf.net/librewolf.repo -o /etc/yum.repos.d/librewolf.repo
dnf5 config-manager setopt librewolf.enabled=0
dnf5 -y install --enablerepo=librewolf librewolf

### MarkFlowy: RPM delle release di GitHub, con versione e sha256 fissati (non c'è un repo).
# Per aggiornare: cambiare le due righe con i valori della release nuova (lo sha256 è nel campo "digest" dell'asset).
MARKFLOWY_VERSION=1.4.0
MARKFLOWY_SHA256=0f00d5cee1603a3da4372d777b66447f500abb20ab37c70875f1dfbaf8b1f50c
curl -fsSL -o /tmp/markflowy.rpm \
    "https://github.com/drl990114/MarkFlowy/releases/download/v${MARKFLOWY_VERSION}/MarkFlowy-${MARKFLOWY_VERSION}-1.x86_64.rpm"
echo "${MARKFLOWY_SHA256}  /tmp/markflowy.rpm" | sha256sum -c -
dnf5 -y install /tmp/markflowy.rpm
rm -f /tmp/markflowy.rpm

### Bitwarden desktop, open source build ("oss-" assets, GPL-3.0; the Flathub one is the commercial "bit-" build):
# password manager and SSH agent (keys from the vault). RPM from the GitHub releases, version and sha256 pinned.
# To update: change the two lines (the sha256 is the "digest" field of oss-Bitwarden-<version>-x86_64.rpm).
# The RPM installs into /opt, which in a bootc image is /var/opt and is only populated at the first install:
# move it under /usr (tmpfiles links it back to /opt for paths written in the app).
BITWARDEN_VERSION=2026.11.0
BITWARDEN_SHA256=b30e042c8e90c23eab9ed8c7fe95632f11ea99ce874131856e987d9bb740f655
curl -fsSL -o /tmp/bitwarden.rpm \
    "https://github.com/bitwarden/clients/releases/download/desktop-v${BITWARDEN_VERSION}/oss-Bitwarden-${BITWARDEN_VERSION}-x86_64.rpm"
echo "${BITWARDEN_SHA256}  /tmp/bitwarden.rpm" | sha256sum -c -
mkdir -p /var/opt
dnf5 -y install /tmp/bitwarden.rpm
rm -f /tmp/bitwarden.rpm
update-alternatives --remove bitwarden /opt/Bitwarden/bitwarden || true
mv /opt/Bitwarden /usr/lib/Bitwarden
ln -sf /usr/lib/Bitwarden/bitwarden /usr/bin/bitwarden
# the RPM makes chrome-sandbox setuid when user namespaces fail, as they may in the build container: Fedora has them
chmod 0755 /usr/lib/Bitwarden/chrome-sandbox
sed -i 's|^Exec=/opt/Bitwarden/bitwarden|Exec=/usr/bin/bitwarden|' /usr/share/applications/bitwarden.desktop
grep -q '^Exec=/usr/bin/bitwarden' /usr/share/applications/bitwarden.desktop

### agent-box: coding agents in a Podman box where every outgoing connection needs an approval (OpenSnitch popup)
# https://github.com/morrolinux/agent-box (MIT). Its images on ghcr.io are not public, so they are built on the
# machine, from these files, by aculos-agent. Pinned to a commit: to update, change the two lines (sha256 of the
# archive GitHub serves for that commit) and check what changed in compose.yaml and entrypoint.sh.
AGENT_BOX_COMMIT=39d3cb6700cc4ca45ef741d0f6154d7a46c80807
AGENT_BOX_SHA256=c17628792730d59e9e1529ad9cba636fe59bcbc33832a22f2bc3233a08302b43
curl -fsSL -o /tmp/agent-box.tar.gz "https://github.com/morrolinux/agent-box/archive/${AGENT_BOX_COMMIT}.tar.gz"
echo "${AGENT_BOX_SHA256}  /tmp/agent-box.tar.gz" | sha256sum -c -
mkdir -p /usr/lib/agent-box
tar -xzf /tmp/agent-box.tar.gz -C /usr/lib/agent-box --strip-components=1
rm -f /tmp/agent-box.tar.gz
rm -rf /usr/lib/agent-box/.github
echo "${AGENT_BOX_COMMIT}" > /usr/lib/agent-box/COMMIT
test -f /usr/lib/agent-box/compose.yaml -a -f /usr/lib/agent-box/Containerfile

### File di sistema del repo (system_files/) copiati in /, dopo i pacchetti così prevalgono sui loro default
cp -avf "/ctx/system_files"/. /

### SELinux: la cartella di stato di noctalia-greeter con l'etichetta dei display manager
# Il pacchetto non porta regole SELinux: la cartella prenderebbe var_lib_t e il greeter (dominio xdm_t) non
# potrebbe sostituire i propri file (AVC "unlink" su sync.toml, visto in VM il 23/11). Stessa etichetta di
# /var/lib/greetd. Sul sistema la applica tmpfiles (riga "Z" in noctalia-greeter.conf).
semanage fcontext -a -N -t xdm_var_lib_t '/var/lib/noctalia-greeter(/.*)?'
grep -q 'noctalia-greeter.*xdm_var_lib_t' /etc/selinux/targeted/contexts/files/file_contexts.local
matchpathcon /var/lib/noctalia-greeter /var/lib/noctalia-greeter/sync.toml || true

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

### Estensioni dei browser, installate da sole (l'utente può disattivarle, non toglierle): Pywalfox (colori dei temi
# di Noctalia, che le fa da host) e Bitwarden (gestore di password, per Vaultwarden). Non in Tor e Mullvad Browser.
# Firefox legge /etc/firefox/policies; per LibreWolf le voci si aggiungono alle sue regole, senza toccare le altre.
python3 -I - <<'PY'
import json, os
amo = "https://addons.mozilla.org/firefox/downloads/latest/{}/latest.xpi"
estensioni = {
    "pywalfox@frewacom.org": {"installation_mode": "normal_installed", "install_url": amo.format("pywalfox")},
    "{446900e4-71c2-419f-a6a7-df9c091e268b}": {"installation_mode": "normal_installed",
                                               "install_url": amo.format("bitwarden-password-manager")},
}
os.makedirs("/etc/firefox/policies", exist_ok=True)
json.dump({"policies": {"ExtensionSettings": estensioni}}, open("/etc/firefox/policies/policies.json", "w"), indent=2)
p = "/usr/share/librewolf/distribution/policies.json"
d = json.load(open(p))
d["policies"].setdefault("ExtensionSettings", {}).update(estensioni)
json.dump(d, open(p, "w"), indent=2)
os.makedirs("/etc/chromium/policies/managed", exist_ok=True)
json.dump({"ExtensionSettings": {"nngceckbapebfimnlniiiahkandclblb": {   # Bitwarden dal Chrome Web Store
    "installation_mode": "normal_installed", "update_url": "https://clients2.google.com/service/update2/crx"}}},
    open("/etc/chromium/policies/managed/aculos-estensioni.json", "w"), indent=2)
PY
grep -q pywalfox /etc/firefox/policies/policies.json
grep -q pywalfox /usr/share/librewolf/distribution/policies.json
grep -q uBlock0 /usr/share/librewolf/distribution/policies.json

### Chromium: i profili nuovi usano il tema GTK, così seguono i colori dei temi di Noctalia (che colora GTK).
# Le preferenze iniziali sono un file del pacchetto chromium: si aggiunge solo la chiave, il resto resta di Fedora.
python3 -I - <<'PY'
import json
p = "/etc/chromium/master_preferences"
d = json.load(open(p))
d.setdefault("extensions", {}).setdefault("theme", {})["system_theme"] = 1   # 1 = GTK
json.dump(d, open(p, "w"), indent=2)
PY
grep -q '"system_theme": 1' /etc/chromium/master_preferences

### Shell: zsh per i nuovi utenti (lo .zshrc di /etc/skel carica i default di /usr/share/aculos/zsh)
sed -i 's|^SHELL=.*|SHELL=/usr/bin/zsh|' /etc/default/useradd
grep -q '^SHELL=/usr/bin/zsh$' /etc/default/useradd

### Servizi di sistema
systemctl enable greetd.service
systemctl enable aculos-greeter-setup.service
systemctl enable tailscaled.service
systemctl enable tuned.service tuned-ppd.service
systemctl enable aculos-impronta-coperchio.service
systemctl enable aculos-flathub.service aculos-flatpak-update.timer
systemctl enable aculos-snapper-home.service snapper-timeline.timer snapper-cleanup.timer
# Servizi utente: partono solo se l'utente ha la loro configurazione in ~/.config/aculos (vedi le unità)
systemctl --global enable syncthing.service aculos-ntfy.service aculos-receive.service kanshi.service
# Il timer utente di GRUB "boot riuscito" qui non serve e fallisce a ogni sessione: la configurazione statica di
# bootupd non usa boot_success, e /boot è montato in sola lettura (visto in VM il 23/11).
systemctl --global disable grub-boot-success.timer
systemctl --global mask grub-boot-success.timer
systemctl set-default graphical.target
# Il login grafico è greetd su tty1: niente getty sullo stesso terminale
systemctl disable getty@tty1.service || true

### Versioni dei componenti principali, per sapere quale build si sta usando
mkdir -p /usr/share/aculos
rpm -q --qf '%{NAME} %{VERSION}-%{RELEASE}\n' \
    noctalia-nightly noctalia-greeter niri greetd kitty tailscale fprintd tuned-ppd syncthing \
    firefox chromium librewolf codium mark-flowy starship kanshi wl-mirror ax86-terminus-ttf-fonts papirus-icon-theme > /usr/share/aculos/versioni.txt
cat /usr/share/aculos/versioni.txt

### Pulizia: niente resti in /run e /var (bootc container lint)
# /var/lib/noctalia-greeter lo riempie il %post del pacchetto durante la build: si svuota, così lo prepara
# aculos-greeter-setup.service al primo avvio, sul sistema vero.
rm -rf /run/dnf /run/selinux-policy /run/tuned /var/lib/dnf /var/lib/noctalia-greeter
