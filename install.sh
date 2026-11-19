#!/bin/bash
# install.sh — instala/reafirma los dotfiles en este host (idempotente).
#   ./install.sh              todo: source en ~/.bashrc, enlaces, hook de auto-push y cron de pull
#   ./install.sh --links-only solo enlaces (lo llama pull.sh tras cada pull)
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CRON_MARKER="# dotfiles-pull"
CRON_LINE="*/20 * * * * ${DOTFILES_DIR}/pull.sh >> ${HOME}/.dotfiles-pull.log 2>&1 ${CRON_MARKER}"

install_links() {
    # sec: enlazado en ~/.local/bin para que también lo vea el shell no interactivo (Claude Code)
    mkdir -p ~/.local/bin
    ln -sfn "$DOTFILES_DIR/sec/sec" ~/.local/bin/sec && echo "✓ sec enlazado en ~/.local/bin"
}

if [ "${1:-}" = "--links-only" ]; then
    install_links
    exit 0
fi

# Agregar source al .bashrc si no existe ya
if ! grep -q "bashrc_common" ~/.bashrc; then
    echo "" >> ~/.bashrc
    echo "# Dotfiles sincronizados" >> ~/.bashrc
    echo "source $DOTFILES_DIR/bashrc_common" >> ~/.bashrc
    echo "✓ bashrc_common agregado a ~/.bashrc"
else
    echo "⚠ bashrc_common ya estaba en ~/.bashrc, no se modificó"
fi

install_links

# Hook post-commit (auto-push) + cron de pull cada 20 min
"$DOTFILES_DIR/pull.sh" --install-only

echo "✓ Instalación completa. Corre: source ~/.bashrc"
