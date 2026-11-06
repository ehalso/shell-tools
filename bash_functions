# @desc Muestra las funciones personalizadas disponibles
helpme() {
  grep -B1 '^[a-zA-Z0-9_-]*() {$' ~/.dotfiles/bash_functions | awk -v aliasfile="$HOME/.dotfiles/bash_aliases" '
    BEGIN {
      while ((getline line < aliasfile) > 0) {
        if (line ~ /^alias [a-zA-Z0-9_-]+='"'"'[a-zA-Z0-9_-]+'"'"'$/) {
          eq = index(line, "=")
          name = substr(line, 7, eq - 7)
          rest = substr(line, eq + 1)
          val = substr(rest, 2, length(rest) - 2)
          aliases[val] = name
        }
      }
    }
    /^# @desc / { desc=substr($0,9) }
    /^[a-zA-Z0-9_-]+\(\) \{$/ {
      sub(/\(\) \{$/,"")
      alias_str = (aliases[$0] != "") ? " (" aliases[$0] ")" : ""
      printf "%-25s %s\n", $0 alias_str, desc
    }
  '
}

# @desc Cambia de workspace/configuración de gcloud
workspace() {
  local workspaces=("erix" "trivasa" "personal")
  local configs=("erix" "trivasa" "default")

  if [ -z "$1" ]; then
    echo "Workspaces disponibles:"
    for i in "${!workspaces[@]}"; do
      echo "  $((i+1))) ${workspaces[$i]}"
    done
    return
  fi

  local selected=""
  if [[ "$1" =~ ^[0-9]+$ ]]; then
    local idx=$(($1 - 1))
    selected="${configs[$idx]}"
  else
    case "$1" in
      erix)     selected="erix" ;;
      trivasa)  selected="trivasa" ;;
      personal) selected="default" ;;
      *)        echo "Workspace no encontrado. Corre 'ws' para ver opciones." ; return 1 ;;
    esac
  fi

  gcloud config configurations activate "$selected"
}

# hosts-ssh (hs) v1.1
#   hs            lista numerada, agrupada por sección de ~/.ssh/config
#   hs -l         selector con búsqueda (requiere fzf)
#   hs N          conecta al número N de la lista
#   hs texto      alias exacto (incluye nombres extra de la línea Host) -> conecta;
#                 si filtra a uno solo, conecta; a varios, abre el selector filtrado;
#                 si no coincide con ninguno, lo pasa tal cual a ssh (ej. root@1.2.3.4)
#
# El grupo de cada host sale del encabezado de sección del config: un comentario
# entre dos líneas "# =====", cuya primera palabra es el grupo (ej. "# TRV — Trivasa").
# Solo se lista el primer nombre de cada línea Host; los alias extra siguen
# funcionando con ssh. Se omiten comodines y alias que apuntan a github.com.
# Los helpers usan "function _x {" para que helpme no los liste.

# Hosts como "grupo<TAB>alias<TAB>hostname<TAB>user", ordenados por grupo y alias.
function _hosts_ssh_entries {
  awk '
    function flush() {
      if (name != "" && name !~ /[*?!]/ && tolower(hn == "" ? name : hn) !~ /(^|\.)github\.com$/)
        printf "%s\t%s\t%s\t%s\n", hgrp, name, (hn != "" ? hn : name), usr
      name = ""; hn = ""; usr = ""
    }
    /^# *=+ *$/            { if (cand != "") { grp = cand; cand = "" } sep = 1; next }
    sep && /^# *[^ ]/      { cand = $2; sep = 0; next }
                           { sep = 0; cand = "" }
    tolower($1) == "host"  { flush(); name = $2; hgrp = grp; next }
    tolower($1) == "match" { flush(); next }
    tolower($1) == "hostname" { hn = $2 }
    tolower($1) == "user"     { usr = $2 }
    END { flush() }
  ' ~/.ssh/config | sort -f -t$'\t' -k1,1 -k2,2
}

function _hosts_ssh_list {
  _hosts_ssh_entries | awk -F'\t' '
    $1 != last { printf "%s\n", $1; last = $1 }
    { printf "  %2d) %-20s %s%s\n", NR, $2, ($4 != "" ? $4 "@" : ""), $3 }'
}

function _hosts_ssh_pick {
  _hosts_ssh_entries | awk -F'\t' '{ printf "%-20s %-4s %s%s\n", $2, $1, ($4 != "" ? $4 "@" : ""), $3 }' |
    fzf --query="$1" --height=60% --reverse --no-sort --prompt='ssh> ' \
        --header='Enter conecta · Esc sale' \
        --preview='ssh -G {1} 2>/dev/null | grep -E "^(hostname|user|port|identityfile|proxyjump) "' \
        --preview-window=down,6 |
    awk '{ print $1 }'
}

# @desc Lista hosts SSH agrupados (hs), selector con búsqueda (hs -l) o conecta por número/nombre
hosts-ssh() {
  local target matches
  if [ -z "$1" ]; then
    _hosts_ssh_list; return
  elif [ "$1" = "-l" ]; then
    command -v fzf >/dev/null || { echo "hs -l requiere fzf" >&2; return 1; }
    target=$(_hosts_ssh_pick)
  elif [[ "$1" =~ ^[0-9]+$ ]]; then
    target=$(_hosts_ssh_entries | sed -n "${1}p" | cut -f2)
    [ -z "$target" ] && { echo "No hay host número $1 (hs para ver la lista)" >&2; return 1; }
  elif awk -v h="$1" 'tolower($1)=="host" { for (i = 2; i <= NF; i++) if ($i == h) f = 1 } END { exit !f }' ~/.ssh/config; then
    target="$1"
  else
    matches=$(_hosts_ssh_entries | cut -f2 | grep -i -F -- "$1")
    if [ -z "$matches" ]; then
      target="$1"
    elif [ "$(printf '%s\n' "$matches" | wc -l)" -eq 1 ]; then
      target="$matches"
    elif command -v fzf >/dev/null; then
      target=$(_hosts_ssh_pick "$1")
    else
      printf '%s\n' "$matches"; return
    fi
  fi
  [ -n "$target" ] && { echo "→ ssh $target"; ssh "$target"; }
}


# @desc Lista VMs de GCP o conecta a la seleccionada
hosts-gcp() {
  local zone_default="us-central1-a"
  local vms=($(gcloud compute instances list --format="value(name)" 2>/dev/null))

  if [ ${#vms[@]} -eq 0 ]; then
    echo "No hay VMs en el proyecto activo ($(gcloud config get-value project 2>/dev/null))."
    echo "Cambia de workspace con: ws"
    return 1
  fi

  if [ -z "$1" ]; then
    echo "VMs disponibles (proyecto: $(gcloud config get-value project 2>/dev/null)):"
    for i in "${!vms[@]}"; do
      echo "  $((i+1))) ${vms[$i]}"
    done
    return
  fi

  local selected=""
  if [[ "$1" =~ ^[0-9]+$ ]]; then
    local idx=$(($1 - 1))
    selected="${vms[$idx]}"
  else
    selected="$1"
  fi

  local zone=$(gcloud compute instances list \
    --filter="name=$selected" \
    --format="value(zone)" 2>/dev/null | awk -F/ '{print $NF}')

  zone="${zone:-$zone_default}"

  echo "Conectando a $selected (zona: $zone)..."
  gcloud compute ssh "$selected" --zone="$zone"
}

# @desc Copia la salida de un pipe al portapapeles (uso: cmd | cb)
copyclipboard() {
  local out
  out=$(cat)
  echo "$out"
  if grep -qi microsoft /proc/version 2>/dev/null; then
    echo "$out" | iconv -t UTF-16LE | clip.exe
  elif [ -n "$DISPLAY" ] || [ -n "$WAYLAND_DISPLAY" ]; then
    echo "$out" | xclip -selection clipboard
  else
    printf '\033]52;c;%s\a' "$(echo "$out" | base64 -w 0)"
  fi
}

# @desc Comandos GCP de referencia rápida
gcphelp() {
  case "$1" in
    "")
      cat << 'GCPEOF'

=== GCP HELP ===

1) Ver configuración activa
   gcloud config list

2) Ver cuentas autenticadas
   gcloud auth list

3) Ver proyectos accesibles
   gcloud projects list

4) Ver máquinas virtuales
   gcloud compute instances list

GCPEOF
      ;;
    1) gcloud config list ;;
    2) gcloud auth list ;;
    3) gcloud projects list ;;
    4) gcloud compute instances list ;;
    *) echo "Opción no válida" ;;
  esac
}



# Redirige "claude" a claude-scratch si se corre desde el home
claude() {
    if [[ "$PWD" == "$HOME" ]]; then
        mkdir -p "$HOME/claude-scratch"
        cd "$HOME/claude-scratch" && command claude "$@"
    else
        command claude "$@"
    fi
}

# @desc Lista conexiones Harlequin o abre la seleccionada (por numero o nombre)
harlequin-connection() {
  local conn_file="$HOME/.config/harlequin/connections"

  if [ ! -f "$conn_file" ]; then
    echo "No existe $conn_file — no hay conexiones configuradas." >&2
    return 1
  fi

  local entries=($(grep -v '^#' "$conn_file" | grep -v '^\s*$' | awk -F'=' '{print $1}'))

  if [ -z "$1" ]; then
    echo "Conexiones disponibles:"
    for i in "${!entries[@]}"; do
      echo "  $((i+1))) ${entries[$i]}"
    done
    return
  fi

  local selected=""
  if [[ "$1" =~ ^[0-9]+$ ]] && [ "$1" -ge 1 ] && [ "$1" -le "${#entries[@]}" ]; then
    selected="${entries[$(($1 - 1))]}"
  else
    selected="$1"
  fi

  local conn
  conn="$(grep -v '^#' "$conn_file" | grep "^${selected}=" | cut -d'=' -f2-)"

  if [ -z "$conn" ]; then
    echo "Conexión no encontrada: $1" >&2
    return 1
  fi

  harlequin -a odbc "$conn"
}

# @desc Corre una query en modo vertical (registro por registro) usando una conexion guardada
#
# Uso:
#   harlequin-vertical                                              lista las conexiones disponibles
#   harlequin-vertical <conexion|numero> "<query>" [limit]           corre una query inline (limit default: 1)
#   harlequin-vertical <conexion|numero> -f archivo.sql [limit]      corre una query desde archivo
#
# Ejemplos:
#   hv
#   hv trivasadb3-205 "SELECT TOP 1 * FROM Orden_Compra ORDER BY Oc_Fecha DESC"
#   hv 1 "SELECT * FROM Orden_Compra WHERE Cm_Cve_Comprador = '0004'" 5
#   hv trivasadb3-205 -f mi_query.sql
#
# Lee las conexiones de ~/.config/harlequin/connections (mismo archivo que harlequin-connection).
harlequin-vertical() {
  local conn_file="$HOME/.config/harlequin/connections"

  if [ ! -f "$conn_file" ]; then
    echo "No existe $conn_file — no hay conexiones configuradas." >&2
    return 1
  fi

  if [ -z "$1" ]; then
    echo "Uso: harlequin-vertical <conexion> <query | -f archivo.sql> [limit]"
    echo ""
    echo "Conexiones disponibles:"
    local entries=($(grep -v '^#' "$conn_file" | grep -v '^\s*$' | awk -F'=' '{print $1}'))
    for i in "${!entries[@]}"; do
      echo "  $((i+1))) ${entries[$i]}"
    done
    return
  fi

  local conn_name="$1"
  shift

  local entries=($(grep -v '^#' "$conn_file" | grep -v '^\s*$' | awk -F'=' '{print $1}'))
  local selected=""
  if [[ "$conn_name" =~ ^[0-9]+$ ]] && [ "$conn_name" -ge 1 ] && [ "$conn_name" -le "${#entries[@]}" ]; then
    selected="${entries[$(($conn_name - 1))]}"
  else
    selected="$conn_name"
  fi

  local conn
  conn="$(grep -v '^#' "$conn_file" | grep "^${selected}=" | cut -d'=' -f2-)"

  if [ -z "$conn" ]; then
    echo "Conexión no encontrada: $conn_name" >&2
    return 1
  fi

  local limit=1
  local query_args=()

  if [ "$1" = "-f" ]; then
    query_args=(-f "$2")
    limit="${3:-1}"
  else
    query_args=(-c "$1")
    limit="${2:-1}"
  fi

  hsql -a odbc "$conn" --limit "$limit" --vertical "${query_args[@]}"
}
