#!/usr/bin/with-contenv bash
set -e

echo "--- DETALLE DE DISPOSITIVOS USB ---"
lsusb
echo "------------------------------------"

CONFIG_PATH=/data/options.json

MQTT_HOST=$(jq -r '.mqtt_host' $CONFIG_PATH)
MQTT_USER=$(jq -r '.mqtt_user' $CONFIG_PATH)
MQTT_PASS=$(jq -r '.mqtt_password' $CONFIG_PATH)
MQTT_PORT=$(jq -r '.mqtt_port' $CONFIG_PATH)
DEVICE=$(jq -r '.device' $CONFIG_PATH)

JSON_FILE="/etc/inverter/mqtt.json"
SCRIPTS_DIR="/opt/inverter-mqtt"
POLLER_BIN="/opt/inverter-cli/inverter_poller"

echo "Usando dispositivo HID: $DEVICE"

# Comprobación real del dispositivo
if [ ! -e "$DEVICE" ]; then
    echo "ERROR: Dispositivo $DEVICE no existe"
    ls -l /dev/hidraw*
    exit 1
fi

ls -l "$DEVICE"

# Parchear MQTT JSON
if [ -f "$JSON_FILE" ]; then
    echo "Configurando $JSON_FILE..."
    sed -i "s@\"server\": \".*\"@\"server\": \"$MQTT_HOST\"@g" "$JSON_FILE"
    sed -i "s@\"port\": \".*\"@\"port\": \"$MQTT_PORT\"@g" "$JSON_FILE"
    sed -i "s@\"username\": \".*\"@\"username\": \"$MQTT_USER\"@g" "$JSON_FILE"
    sed -i "s@\"password\": \".*\"@\"password\": \"$MQTT_PASS\"@g" "$JSON_FILE"

    mkdir -p /opt/inverter-cli/bin
    ln -sf "$POLLER_BIN" /opt/inverter-cli/bin/inverter_poller
fi

cd "$SCRIPTS_DIR"

echo "Preparando compatibilidad hiddev..."

mkdir -p /dev/usb

if [ ! -e /dev/usb/hiddev0 ]; then
    ln -s /dev/hidraw0 /dev/usb/hiddev0
fi

ls -l /dev/usb/hiddev0

echo "Prueba directa de lectura HID..."
"$POLLER_BIN" -d -p "$DEVICE" || {
    echo "ERROR: fallo acceso HID"
    exit 1
}

echo "Iniciando procesos..."
/bin/bash ./mqtt-init.sh
watch -n 300 /bin/bash ./mqtt-init.sh > /dev/null 2>&1 &
/bin/bash ./mqtt-subscriber.sh &

exec watch -n 30 /bin/bash ./mqtt-push.sh
