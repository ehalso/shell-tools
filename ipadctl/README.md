# ipadctl

Controla un **iPad Air 1 (iOS 12.5.7) con jailbreak Amethyst** por SSH: abrir URLs, tocar,
deslizar, ver la pantalla y volver al Inicio. Un solo archivo Python, sin dependencias de pip.

La pantalla se ve por **AirPlay** con [UxPlay](https://github.com/FDH2/UxPlay) corriendo en el host,
sin ventana: guarda el último fotograma como JPEG (`shot`).

## Requisitos

**En el iPad** (jailbreak rootful, iOS 12):
- OpenSSH y `uikittools` (`uiopen`).
- **Activator** (`libactivator`) para `home` y `unlock`.
- **ZXTouch** (`com.zjx.ioscontrol`) para toques; escucha en `127.0.0.1:6000`.

**En el host** (probado en WSL2 Ubuntu 24.04): `python3`, `ssh`, `sshpass`, `uxplay`,
`avahi-daemon` y los plugins de GStreamer (`plugins-good`, `plugins-bad`, `libav`).

## Configuración

| Variable | Uso |
|---|---|
| `IPAD_HOST` | IP o nombre del iPad (obligatoria) |
| `IPAD_USER` | usuario SSH (def. `root`) |
| `IPAD_SSH_PASS` | contraseña; si falta se lee de Infisical |
| `IPADCTL_INFISICAL_PROJECT` | proyecto de Infisical (def. `Estebanalcocer.cloud`, env `prod`, secreto `IPAD_SSH_PASS`) |
| `IPADCTL_DIR` | carpeta de estado y fotogramas (def. `~/.cache/ipadctl`) |
| `IPADCTL_MIRROR_NAME` | nombre AirPlay del receptor (def. `WSL-UxPlay`) |

## Uso

```
ipadctl status                      # SSH, ZXTouch, orientación, batería, app, espejo
ipadctl mirror start                # arranca UxPlay; en el iPad: Duplicar pantalla > WSL-UxPlay
ipadctl shot -o pantalla.jpg        # último fotograma (1 por segundo, solo si la pantalla cambia)
ipadctl tap 720 121                 # toque en la posición que ves en la imagen de shot
ipadctl swipe 720 900 720 300       # deslizar (dedo hacia arriba = scroll hacia abajo)
ipadctl open https://example.com    # abre la URL en Safari
ipadctl home | unlock | app
ipadctl run <comando>               # ejecuta un comando en el iPad
```

`tap` y `swipe` reciben coordenadas **del fotograma** y el script las convierte. Con `--raw`
se pasan coordenadas crudas de ZXTouch y con `--norm`, fracciones 0..1 de la vista.

## Lo aprendido (para no repetirlo)

**Coordenadas de ZXTouch**
- Están en **píxeles** del iPad en vertical (1536×2048), no en puntos.
- Con el iPad en horizontal (orientación 4) el eje X de ZXTouch recorre la pantalla de
  arriba a abajo: `x = v_px`, `y = 2048 − u_px`. Verificado con taps.
- Las orientaciones 2 y 3 están **deducidas, no verificadas**.

**Red**
- Con la pantalla bloqueada las conexiones SSH **nuevas** fallan casi siempre
  (`No route to host`), pero una sesión **ya establecida sobrevive** al bloqueo (13 min probados).
  Por eso el script usa `ControlMaster` y mantiene la conexión 30 min.
- El tweak iNoSleep (mantener Wi-Fi con pantalla bloqueada) **no mostró beneficio demostrable**.
- Un Wi-Fi inestable (repetidor de una sola radio) causa cortes parecidos y se confunde fácil
  con el bloqueo de pantalla: conviene comparar contra otro dispositivo de la misma red.

**UxPlay en WSL2**
- El modo de red `nat` de WSL no sirve: el iPad no alcanza a WSL y el mDNS no cruza.
  Usar `networkingMode=mirrored` en `.wslconfig` y abrir el firewall de Hyper-V:
  `Set-NetFirewallHyperVVMSetting -Name '{40E0AC32-46A5-438A-A0B2-2B479E8F2E90}' -DefaultInboundAction Allow`
  (PowerShell como administrador; abre todo el tráfico entrante hacia WSL).
- **`-vsync no` es imprescindible**: sin él UxPlay arranca el streaming pero no entrega ni un fotograma.

**Instalar en iOS 12**
- `libactivator` viene de BigBoss, que ya no tiene llave GPG: `apt` exige
  `--allow-unauthenticated`. Es una decisión consciente, no un descuido.
- El repo `zxtouch.net` ya no existe. El `.deb` está en los *Releases* de GitHub de
  `xuan32546/IOS13-SimulateTouch`; el `0.0.7-10` trae un `preinst` sin salto de línea final
  que hace fallar `dpkg` con `Invalid argument` (hay que reempaquetarlo con `\n`).
- ZXTouch corre **dentro de SpringBoard**: no aparece en `ps` y necesita un respring tras instalar.

## Sin verificar

`mirror start/stop`, `shot --native`, `run` y las orientaciones 1, 2 y 3.
