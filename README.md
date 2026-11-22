# shell-tools
Funciones y aliases de bash sincronizados entre VMs

- `bash_functions`, `bash_aliases`, `bashrc_common` — se cargan desde `~/.bashrc` (`install.sh`).
- `ipadctl/` — control del iPad por SSH (ver su README).
- `cred/` — secretos efímeros en RAM para pasarlos a Claude Code sin que el valor pase por el chat
  (`cred`, `cred ls`, `cred rm`, `cred run`, `cred dir`, `cred -m`; aliases `credls`/`credrm`/`credrun`). `install.sh` lo enlaza en `~/.local/bin/cred` (no se llama `sec` porque choca con el paquete apt `sec`).
- `unveil/` — muestra y copia al portapapeles un secreto de Infisical (`unveil NOMBRE [CARPETA]`, `unveil ls`). **Solo para humanos**: se niega a imprimir si la salida no es un terminal. No se llama `sec` ni `peek` porque chocan con paquetes apt.

## Sincronización
- `install.sh` (una vez por host): source en `~/.bashrc`, enlaces (`cred`), hook `post-commit` que hace push y cron `*/20` con `pull.sh` (marca `# dotfiles-pull`, log en `~/.dotfiles-pull.log`).
- `pull.sh`: `git pull --ff-only` y, si bajó cambios, `install.sh --links-only`. Las funciones/aliases nuevos aplican en shells nuevos o con `source ~/.bashrc`.
