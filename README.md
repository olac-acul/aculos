# aculOs

Distribuzione Linux immutabile personale, costruita come immagine [bootc](https://bootc-dev.github.io/bootc/)
sopra [Universal Blue](https://universal-blue.org/) `base-main` (Fedora). Pensata per un ThinkPad X1 Carbon Gen 11,
con [niri](https://github.com/YaLTeR/niri) e [Noctalia](https://github.com/noctalia-dev/noctalia-shell).

È un progetto personale: le scelte seguono un uso preciso e possono cambiare senza preavviso.

> **Stato:** fase 3, preparazione dell'hardware: impronta digitale (anche nel blocco schermo, staccata a coperchio chiuso), profili energetici con tuned-ppd, soglie di carica. Sopra la base della fase 2: niri, Noctalia, noctalia-greeter su greetd, portali, gnome-keyring, Tailscale.

## Struttura

| Percorso | Cosa contiene |
| --- | --- |
| `Containerfile` | immagine di base e passi della build |
| `build_files/build.sh` | pacchetti e configurazione del sistema |
| `system_files/` | file copiati così come sono nell'immagine (`/usr`, `/etc`) |
| `disk_config/` | configurazione per le immagini disco e le ISO |
| `Justfile` | comandi per costruire e provare l'immagine in locale |

GitHub Actions costruisce l'immagine a ogni modifica e ogni giorno, la pubblica su GHCR e la firma con cosign.

## Uso

Da un sistema bootc o Fedora Atomic già installato:

```bash
sudo bootc switch ghcr.io/olac-acul/aculos:latest
```

Verifica della firma:

```bash
cosign verify --key cosign.pub ghcr.io/olac-acul/aculos:latest
```

## Licenza

Apache-2.0, come il [template di Universal Blue](https://github.com/ublue-os/image-template) da cui parte.
