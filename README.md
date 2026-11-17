# shell-tools
Funciones y aliases de bash sincronizados entre VMs

- `bash_functions`, `bash_aliases`, `bashrc_common` — se cargan desde `~/.bashrc` (`install.sh`).
- `ipadctl/` — control del iPad por SSH (ver su README).
- `sec/` — secretos efímeros en RAM para pasarlos a Claude Code sin que el valor pase por el chat
  (`sec`, `sec ls`, `sec rm`, `sec run`, `sec dir`, `sec -m`; aliases `secls`/`secrm`/`secrun`). `install.sh` lo enlaza en `~/.local/bin/sec`.
