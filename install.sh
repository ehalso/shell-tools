#!/bin/bash
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Agregar source al .bashrc si no existe ya
if ! grep -q "bashrc_common" ~/.bashrc; then
    echo "" >> ~/.bashrc
    echo "# Dotfiles sincronizados" >> ~/.bashrc
    echo "source $DOTFILES_DIR/bashrc_common" >> ~/.bashrc
    echo "✓ bashrc_common agregado a ~/.bashrc"
else
    echo "⚠ bashrc_common ya estaba en ~/.bashrc, no se modificó"
fi

echo "✓ Instalación completa. Corre: source ~/.bashrc"

# sec: script de secretos efímeros, enlazado en ~/.local/bin para que también lo vea el shell no interactivo (Claude Code)
mkdir -p ~/.local/bin
ln -sfn "$DOTFILES_DIR/sec/sec" ~/.local/bin/sec && echo "✓ sec enlazado en ~/.local/bin"
