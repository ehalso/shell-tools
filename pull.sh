#!/usr/bin/env bash
# pull.sh — dos modos:
#   - sin argumentos: pull periódico (lo llama el cron cada 20 min). Falla rápido
#     y en silencio ante problemas de red/auth; si bajó cambios, reafirma enlaces.
#   - --install-only: instala/reafirma el hook de auto-push y el cron
#     (lo llama install.sh; se puede correr a mano si cambia este script).
# Mismo patrón que ~/.claude/skills/tools/pull.sh.

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK_PATH="${DOTFILES_DIR}/.git/hooks/post-commit"
CRON_MARKER="# dotfiles-pull"
CRON_LINE="*/20 * * * * ${DOTFILES_DIR}/pull.sh >> ${HOME}/.dotfiles-pull.log 2>&1 ${CRON_MARKER}"

write_hook() {
  cat > "$HOOK_PATH" <<'HOOK'
#!/usr/bin/env bash
# Auto-generado por pull.sh — no editar a mano, se reescribe en cada corrida.
# Empuja cada commit en cuanto se hace para que no se quede solo local.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
if ! GIT_TERMINAL_PROMPT=0 git push 2>&1; then
  echo "post-commit: push falló (revisar conectividad/credenciales) — el commit local sí quedó hecho" >&2
fi
exit 0
HOOK
  chmod +x "$HOOK_PATH"
}

install_cron() {
  local current
  current=$(crontab -l 2>/dev/null || true)
  {
    echo "$current" | grep -vF "$CRON_MARKER" || true
    echo "$CRON_LINE"
  } | grep -v '^$' | crontab -
}

if [ "${1:-}" = "--install-only" ]; then
  write_hook
  install_cron
  echo "✓ hook de auto-push y cron de pull instalados/actualizados"
  exit 0
fi

write_hook
before=$(git -C "$DOTFILES_DIR" rev-parse HEAD)
GIT_TERMINAL_PROMPT=0 git -C "$DOTFILES_DIR" pull --ff-only
after=$(git -C "$DOTFILES_DIR" rev-parse HEAD)
if [ "$before" != "$after" ]; then
  "$DOTFILES_DIR/install.sh" --links-only
fi
