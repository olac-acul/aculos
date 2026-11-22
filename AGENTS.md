# aculos

Immagine bootc di aculOs. Repository **pubblico**.

## Regole
- Rispondi in italiano.
- **Niente dati personali o della rete di casa** in questo repo: niente segreti, domini, indirizzi IP, nomi delle
  macchine, email. La parte personale sta nei dotfiles privati. Un controllo prima del commit e uno in CI lo
  verificano: se scatta, togli il dato invece di aggirare il controllo.
- Il sistema si cambia solo da qui: `Containerfile`, `build_files/`, `system_files/`.
- Contenuto di sistema in `/usr` (`/usr/lib/…`, `/usr/share/aculos/`); `/etc` il meno possibile.
- Repo esterni (Terra, LibreWolf…) abilitati solo per i pacchetti che servono, poi disattivati.
- Mai `cosign.key` nel repo (è nel `.gitignore`); `cosign.pub` sì.
