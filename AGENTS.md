# aculos

The aculOs bootc image. This repository is **public**.

## Rules
- **No personal or home-network data** in this repo: no secrets, domains, IP addresses, machine names or emails.
  Personal settings live in private dotfiles. A pre-commit check and a CI check look for them: if one fires, remove
  the data instead of working around the check.
- Everything in this repo is in English: code, comments, file names and documentation.
- The system changes only from here: `Containerfile`, `build_files/`, `system_files/`.
- System content goes in `/usr` (`/usr/lib/…`, `/usr/share/aculos/`); keep `/etc` to a minimum.
- External repositories (Terra, LibreWolf…) are enabled only for the packages needed, then disabled.
- Open source software only (OSI license, checked on the build actually installed).
- Never commit `cosign.key` (it is in `.gitignore`); `cosign.pub` is fine.
