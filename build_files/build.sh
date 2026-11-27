#!/bin/bash
# aculOs build: runs inside the Containerfile, on top of base-main.
# Rule for external repos (Terra, LibreWolf...): enable them only for the packages needed, then disable them.

set -ouex pipefail

### Fedora packages
# Phase 2: desktop base (niri, greeter, portals, keyring, terminal, Tailscale)
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
# niri brings along, as recommended dependencies, the programs of its example configuration. In aculOs they are
# replaced by kitty (terminal) and Noctalia (bar, launcher, lock screen): remove them, so they don't show in the menu.
dnf5 -y remove alacritty fuzzel swaylock waybar

# Phase 3: laptop. tuned-ppd instead of power-profiles-daemon (same D-Bus interface, which Noctalia uses);
# intel-lpmd and thermald are already in the base.
dnf5 -y swap power-profiles-daemon tuned-ppd
dnf5 -y install \
    fprintd \
    fprintd-pam

# Phase 5: commands used by the Noctalia plugins (udiskie for USB sticks)
dnf5 -y install udiskie

# Phase 4: Syncthing and the system apps (file manager with thumbnails, terminal editor, clipboard, GTK3 theme)
dnf5 -y install \
    syncthing \
    nautilus \
    gvfs \
    ffmpegthumbnailer \
    micro \
    wl-clipboard \
    adw-gtk3-theme

# Phase 5: shell, terminal tools, browsers
dnf5 -y install \
    zsh zsh-autosuggestions zsh-syntax-highlighting \
    eza bat ripgrep fd-find fzf jq btop duf plocate \
    rsync pv socat wget2-wget unzip 7zip unrar snapper restic \
    chezmoi nodejs nodejs-npm \
    igt-gpu-tools ethtool \
    flatpak distrobox podman podman-compose \
    firefox chromium

# Phase 5: external displays. kanshi reapplies the layout saved for each combination of displays (the profiles are
# written by aculos-display), wl-mirror mirrors one display onto another, wlr-randr is for diagnostics.
dnf5 -y install kanshi wl-mirror wlr-randr

# Phase 5: for the alternative desktop themes: the Terminus bitmap-style font in TrueType (family "Terminus (TTF)")
# and the Papirus icons (the colored folders are derived by the themes command, for the user)
dnf5 -y install ax86-terminus-ttf-fonts papirus-icon-theme papirus-icon-theme-dark

### Terra packages (Noctalia)
# terra-release brings the repo file and the GPG key; the repo stays installed but disabled,
# and is enabled only for the packages needed.
dnf5 -y install --nogpgcheck --repofrompath 'terra,https://repos.fyralabs.com/terra$releasever' terra-release
dnf5 config-manager setopt terra.enabled=0
dnf5 -y install --enablerepo=terra \
    noctalia-nightly \
    noctalia-greeter

# Phase 5, also from Terra: prompt, bw for chezmoi, mise to try out tools in user space, VSCodium
dnf5 -y install --enablerepo=terra \
    starship \
    bitwarden-cli \
    mise \
    codium

### LibreWolf from its official repo (installed but disabled, like Terra)
curl -fsSL https://repo.librewolf.net/librewolf.repo -o /etc/yum.repos.d/librewolf.repo
dnf5 config-manager setopt librewolf.enabled=0
dnf5 -y install --enablerepo=librewolf librewolf

### MarkFlowy: RPM from the GitHub releases, version and sha256 pinned (there is no repo).
# To update: change the two lines to the values of the new release (the sha256 is the "digest" field of the asset).
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

### The repo's system files (system_files/) copied to /, after the packages so they override their defaults
cp -avf "/ctx/system_files"/. /

### SELinux: the noctalia-greeter state folder with the display manager label
# The package ships no SELinux rules: the folder would get var_lib_t and the greeter (domain xdm_t) could not
# replace its own files (AVC "unlink" on sync.toml, seen in the VM on Nov 23). Same label as /var/lib/greetd.
# On the installed system tmpfiles applies it ("Z" line in noctalia-greeter.conf).
semanage fcontext -a -N -t xdm_var_lib_t '/var/lib/noctalia-greeter(/.*)?'
grep -q 'noctalia-greeter.*xdm_var_lib_t' /etc/selinux/targeted/contexts/files/file_contexts.local
matchpathcon /var/lib/noctalia-greeter /var/lib/noctalia-greeter/sync.toml || true

### Fingerprint: the standard Fedora way (authselect), with two exceptions
# The fingerprint works for everything that uses system-auth (sudo, su, polkit). The greeter and the "login" PAM
# service (the password of the Noctalia lock screen) use password-auth instead, which authselect leaves without
# pam_fprintd: the greeter needs the password to unlock the keyring, and the lock screen asks fprintd for the
# fingerprint directly, on its own.
authselect enable-feature with-fingerprint
grep -q pam_fprintd /etc/authselect/system-auth
if grep -q pam_fprintd /etc/authselect/password-auth; then echo "pam_fprintd in password-auth" >&2; exit 1; fi
sed -E 's/^(auth[[:space:]]+substack[[:space:]]+)system-auth$/\1password-auth/' \
    /usr/lib/pam.d/greetd > /etc/pam.d/greetd
sed -i -E 's/^(auth[[:space:]]+substack[[:space:]]+)system-auth$/\1password-auth/' /etc/pam.d/login
grep -q -E '^auth[[:space:]]+substack[[:space:]]+password-auth$' /etc/pam.d/greetd
grep -q -E '^auth[[:space:]]+substack[[:space:]]+password-auth$' /etc/pam.d/login

### Signature: bootc accepts aculOs only if signed with the repo key (cosign.pub)
# Same rule the base uses for the Universal Blue images. After the installation (which pulls the image
# without verifying it) the kickstart switches to it with bootc switch --enforce-container-sigpolicy.
install -D -m 644 /ctx/cosign.pub /etc/pki/containers/aculos.pub
python3 -I - <<'EOF'
import json
p = "/etc/containers/policy.json"
with open(p) as f:
    policy = json.load(f)
# GHCR, and Quay as the second registry (same image, signed there with the same key)
for repo in ("ghcr.io/olac-acul/aculos", "quay.io/olac-acul/aculos"):
    policy["transports"]["docker"][repo] = [{
        "type": "sigstoreSigned",
        "keyPath": "/etc/pki/containers/aculos.pub",
        "signedIdentity": {"type": "matchRepository"},
    }]
with open(p, "w") as f:
    json.dump(policy, f, indent=4)
    f.write("\n")
EOF
grep -q '"ghcr.io/olac-acul/aculos"' /etc/containers/policy.json
grep -q '"quay.io/olac-acul/aculos"' /etc/containers/policy.json

### Noctalia as a user service tied to the niri session
# The service is the one shipped by Noctalia, with the WantedBy for niri enabled.
sed 's/^# WantedBy=niri.service$/WantedBy=niri.service/' \
    /usr/share/noctalia/assets/noctalia.service > /usr/lib/systemd/user/noctalia.service
grep -q '^WantedBy=niri.service$' /usr/lib/systemd/user/noctalia.service
systemctl --global enable noctalia.service

### Default niri configuration
mkdir -p /etc/niri
ln -sf /usr/share/aculos/niri/config.kdl /etc/niri/config.kdl

### Browser extensions, installed automatically (the user can disable them, not remove them): Pywalfox (colors of
# the Noctalia themes, Noctalia acts as its host) and Bitwarden (password manager, for Vaultwarden). Not in Tor and
# Mullvad Browser. Firefox reads /etc/firefox/policies; for LibreWolf the entries are added to its policies,
# leaving the others alone.
python3 -I - <<'PY'
import json, os
amo = "https://addons.mozilla.org/firefox/downloads/latest/{}/latest.xpi"
extensions = {
    "pywalfox@frewacom.org": {"installation_mode": "normal_installed", "install_url": amo.format("pywalfox")},
    "{446900e4-71c2-419f-a6a7-df9c091e268b}": {"installation_mode": "normal_installed",
                                               "install_url": amo.format("bitwarden-password-manager")},
}
os.makedirs("/etc/firefox/policies", exist_ok=True)
json.dump({"policies": {"ExtensionSettings": extensions}}, open("/etc/firefox/policies/policies.json", "w"), indent=2)
p = "/usr/share/librewolf/distribution/policies.json"
d = json.load(open(p))
d["policies"].setdefault("ExtensionSettings", {}).update(extensions)
json.dump(d, open(p, "w"), indent=2)
os.makedirs("/etc/chromium/policies/managed", exist_ok=True)
json.dump({"ExtensionSettings": {"nngceckbapebfimnlniiiahkandclblb": {   # Bitwarden from the Chrome Web Store
    "installation_mode": "normal_installed", "update_url": "https://clients2.google.com/service/update2/crx"}}},
    open("/etc/chromium/policies/managed/aculos-extensions.json", "w"), indent=2)
PY
grep -q pywalfox /etc/firefox/policies/policies.json
grep -q pywalfox /usr/share/librewolf/distribution/policies.json
grep -q uBlock0 /usr/share/librewolf/distribution/policies.json

### Chromium: new profiles use the GTK theme, so they follow the colors of the Noctalia themes (which color GTK).
# The initial preferences are a file of the chromium package: only the key is added, the rest stays as Fedora's.
python3 -I - <<'PY'
import json
p = "/etc/chromium/master_preferences"
d = json.load(open(p))
d.setdefault("extensions", {}).setdefault("theme", {})["system_theme"] = 1   # 1 = GTK
json.dump(d, open(p, "w"), indent=2)
PY
grep -q '"system_theme": 1' /etc/chromium/master_preferences

### Shell: zsh for new users (the .zshrc in /etc/skel loads the defaults from /usr/share/aculos/zsh)
sed -i 's|^SHELL=.*|SHELL=/usr/bin/zsh|' /etc/default/useradd
grep -q '^SHELL=/usr/bin/zsh$' /etc/default/useradd

### System services
systemctl enable greetd.service
systemctl enable aculos-greeter-setup.service
systemctl enable tailscaled.service
systemctl enable tuned.service tuned-ppd.service
systemctl enable aculos-fingerprint-lid.service
systemctl enable aculos-flathub.service aculos-flatpak-update.timer
systemctl enable aculos-snapper-home.service snapper-timeline.timer snapper-cleanup.timer
# User services: they start only if the user has their configuration in ~/.config/aculos (see the units)
systemctl --global enable syncthing.service aculos-ntfy.service aculos-receive.service kanshi.service
systemctl --global enable aculos-update-notify.service aculos-update-notify.path
# GRUB's "boot succeeded" user timer is not needed here and fails at every session: bootupd's static configuration
# does not use boot_success, and /boot is mounted read-only (seen in the VM on Nov 23).
systemctl --global disable grub-boot-success.timer
systemctl --global mask grub-boot-success.timer
systemctl set-default graphical.target
# The graphical login is greetd on tty1: no getty on the same terminal
systemctl disable getty@tty1.service || true

### Versions of the main components, to know which build is in use
mkdir -p /usr/share/aculos
rpm -q --qf '%{NAME} %{VERSION}-%{RELEASE}\n' \
    noctalia-nightly noctalia-greeter niri greetd kitty tailscale fprintd tuned-ppd syncthing \
    firefox chromium librewolf codium mark-flowy starship kanshi wl-mirror ax86-terminus-ttf-fonts papirus-icon-theme > /usr/share/aculos/versions.txt
cat /usr/share/aculos/versions.txt

### Cleanup: no leftovers in /run and /var (bootc container lint)
# /var/lib/noctalia-greeter is filled by the package's %post during the build: empty it, so that
# aculos-greeter-setup.service prepares it at first boot, on the real system.
rm -rf /run/dnf /run/selinux-policy /run/tuned /var/lib/dnf /var/lib/noctalia-greeter
