# @desc Muestra las funciones personalizadas disponibles
helpme() {
  grep -B1 '^[a-zA-Z0-9_-]*() {$' ~/.dotfiles/bash_functions | awk -v aliasfile="$HOME/.dotfiles/bash_aliases" '
    BEGIN {
      while ((getline line < aliasfile) > 0) {
        if (match(line, /^alias ([a-zA-Z0-9_-]+)='"'"'([a-zA-Z0-9_-]+)'"'"'/, arr)) {
          aliases[arr[2]] = arr[1]
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
    echo "$out" | clip.exe
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

