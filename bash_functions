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

# @desc Lista hosts SSH o conecta al seleccionado
hosts-ssh() {
  local entries=($(grep "^Host " ~/.ssh/config | awk '{print $2}' | grep -v '^\*'))
  if [ -z "$1" ]; then
    echo "Hosts disponibles:"
    for i in "${!entries[@]}"; do
      echo "  $((i+1))) ${entries[$i]}"
    done
    return
  fi
  if [[ "$1" =~ ^[0-9]+$ ]]; then
    local idx=$(($1 - 1))
    ssh "${entries[$idx]}"
  else
    ssh "$1"
  fi
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
