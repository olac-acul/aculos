<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="system_files/usr/share/aculos/logo/aculos-logo.svg">
    <img src="system_files/usr/share/aculos/logo/aculos-logo-light.svg" alt="aculOs" width="360">
  </picture>
</p>

# aculOs

A personal, immutable Linux desktop built as a [bootc](https://bootc-dev.github.io/bootc/) image on top of
[Universal Blue](https://universal-blue.org/) `base-main` (Fedora). Made for a ThinkPad X1 Carbon Gen 11, with the
[niri](https://github.com/YaLTeR/niri) scrolling compositor and the [Noctalia](https://github.com/noctalia-dev/noctalia-shell) shell.

It is a personal project: choices follow one person's use and may change at any time.

## What's inside

- niri + Noctalia, with noctalia-greeter on greetd
- `aculos` command for everyday tasks, also as a menu in the launcher (Mod+Space); `aculos theme` switches
  between three desktop themes (squared, rounded, blue-dos) across Noctalia, niri, kitty, GTK apps and Firefox
- Laptop tuning: fingerprint login, battery charge thresholds, tuned power profiles, zram
- Tailscale, Syncthing, rootless Podman, snapshots of `/var/home` with snapper
- `aculos-agent`: coding agents (pi, Claude Code, Codex) in a sandboxed container, with OpenSnitch asking before
  every outbound connection
- Open source apps only (Claude Code, if used, runs only inside the agent box)

## Install

From any bootc or Fedora Atomic system:

```bash
sudo bootc switch ghcr.io/olac-acul/aculos:latest
```

Images are built daily by GitHub Actions and signed with cosign:

```bash
cosign verify --key cosign.pub ghcr.io/olac-acul/aculos:latest
```

## Credits

- [Universal Blue image template](https://github.com/ublue-os/image-template), which this repository starts from
- [niri](https://github.com/YaLTeR/niri), [Noctalia](https://github.com/noctalia-dev/noctalia-shell) and
  [Terra](https://terra.fyralabs.com/) for packages not in Fedora
- The blue-dos theme is inspired by Hyprland-Desktop-Viola-Blu from
  [RiccardoPP/dotfiles](https://github.com/RiccardoPP/dotfiles) (MIT, Copyright (c) 2024 Riccardo Palombo)

## License

Apache-2.0, like the Universal Blue template.
