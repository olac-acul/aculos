# aculOs: micro is the default editor in login shells, and so in the graphical session, which imports the
# environment of the login shell. This file is read before nano-default-editor.sh, which sets EDITOR only
# when it is still unset. To use another editor, export EDITOR and VISUAL in your own shell configuration.
[ -n "${EDITOR:-}" ] || export EDITOR=micro
[ -n "${VISUAL:-}" ] || export VISUAL=micro
