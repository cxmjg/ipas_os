#!/bin/bash

set -e

KIOSK_USER="kiosk"
DESKTOP_ENV="xfce"   # Cambia según tu entorno: lxde, mate, etc.
MARKER_FILE="/etc/kiosk_mode_enabled"
LIGHTDM_CONF="/etc/lightdm/lightdm.conf"
XSESSION_FILE="/home/$KIOSK_USER/.xsession"

function install_kiosk() {
    echo "=== Instalando modo kiosco ==="

    read -rp "Ingrese la URL que debe abrir el kiosco: " URL

    echo "=== Actualizando sistema e instalando Chromium..."
    sudo apt update
    sudo apt install -y chromium-browser lightdm

    echo "=== Creando usuario '$KIOSK_USER'..."
    if id -u "$KIOSK_USER" &>/dev/null; then
        echo "El usuario '$KIOSK_USER' ya existe."
    else
        sudo adduser --disabled-password --gecos "" "$KIOSK_USER"
    fi

    echo "=== Configurando auto-login en LightDM..."
    sudo mkdir -p "$(dirname "$LIGHTDM_CONF")"
    cat <<EOF | sudo tee "$LIGHTDM_CONF"
[SeatDefaults]
autologin-user=$KIOSK_USER
autologin-user-timeout=0
user-session=$DESKTOP_ENV
[Seat:*]
xserver-command=X -s 0 dpms
EOF

    echo "=== Creando sesión de kiosco para el usuario..."
    cat <<EOF | sudo tee "$XSESSION_FILE"
#!/bin/bash
xset -dpms
xset s off
xset s noblank
chromium-browser --noerrdialogs --kiosk --incognito $URL
EOF
    sudo chmod +x "$XSESSION_FILE"
    sudo chown "$KIOSK_USER":"$KIOSK_USER" "$XSESSION_FILE"

    echo "=== Marcando sistema como kiosco ==="
    echo "URL=$URL" | sudo tee "$MARKER_FILE" > /dev/null

    echo "=== Instalación completada. Reinicie el sistema para aplicar cambios. ==="
}

function update_url() {
    read -rp "Ingrese la nueva URL del kiosco: " URL
    echo "=== Actualizando URL a $URL ==="

    cat <<EOF | sudo tee "$XSESSION_FILE"
#!/bin/bash
xset -dpms
xset s off
xset s noblank
chromium-browser --noerrdialogs --kiosk --incognito $URL
EOF
    sudo chown "$KIOSK_USER":"$KIOSK_USER" "$XSESSION_FILE"

    echo "URL=$URL" | sudo tee "$MARKER_FILE" > /dev/null
    echo "=== URL actualizada correctamente. Reinicie para aplicar. ==="
}

function uninstall_kiosk() {
    echo "=== Desinstalando modo kiosco ==="
    sudo rm -f "$MARKER_FILE"
    sudo rm -f "$LIGHTDM_CONF"
    sudo rm -f "$XSESSION_FILE"
    sudo deluser --remove-home "$KIOSK_USER" || true
    echo "=== Modo kiosco desinstalado. Reinicie para volver al estado normal. ==="
}

# --- Lógica principal ---
if [ -f "$MARKER_FILE" ]; then
    source "$MARKER_FILE"
    echo "El sistema ya está configurado en modo kiosco."
    echo "URL actual: $URL"
    echo "¿Qué desea hacer?"
    echo "1) Actualizar URL"
    echo "2) Desinstalar modo kiosco"
    echo "3) Cancelar"
    read -rp "Seleccione una opción [1-3]: " choice
    case $choice in
        1) update_url ;;
        2) uninstall_kiosk ;;
        *) echo "Cancelado." ;;
    esac
else
    install_kiosk
fi
