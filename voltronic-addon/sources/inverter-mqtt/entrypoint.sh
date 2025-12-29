#!/bin/bash
echo "--- DETALLE DE DISPOSITIVOS USB ---"
lsusb
echo "------------------------------------"

export TERM=xterm
CONFIG_PATH=/data/options.json

# 1. Leer configuración
MQTT_HOST=$(jq --raw-output '.mqtt_host' $CONFIG_PATH)
MQTT_USER=$(jq --raw-output '.mqtt_user' $CONFIG_PATH)
MQTT_PASS=$(jq --raw-output '.mqtt_password' $CONFIG_PATH)
MQTT_PORT=$(jq --raw-output '.mqtt_port' $CONFIG_PATH)

# 2. Rutas
JSON_FILE="/etc/inverter/mqtt.json"
SCRIPTS_DIR="/opt/inverter-mqtt"
POLLER_BIN="/opt/inverter-cli/inverter_poller"

# --- NUEVO: CONFIGURACIÓN DE PERMISOS PARA HID ---
echo "Configurando permisos para dispositivo HID (0665:5161)..."
# Dar permisos a los buses USB
chmod -R 777 /dev/bus/usb/
# Crear y dar permisos al nodo hidraw si el sistema lo permite
mknod /dev/hidraw0 c 242 0 2>/dev/null
chmod 666 /dev/hidraw0 2>/dev/null
# -------------------------------------------------

# 3. Parchear el JSON
if [ -f "$JSON_FILE" ]; then
    echo "Configurando $JSON_FILE..."
    sed -i "s@\[HA_MQTT_IP\]@$MQTT_HOST@g" "$JSON_FILE"
    sed -i "s@\"server\": \".*\"@\"server\": \"$MQTT_HOST\"@g" "$JSON_FILE"
    sed -i "s@\"port\": \".*\"@\"port\": \"$MQTT_PORT\"@g" "$JSON_FILE"
    sed -i "s@\"username\": \".*\"@\"username\": \"$MQTT_USER\"@g" "$JSON_FILE"
    sed -i "s@\"password\": \".*\"@\"password\": \"$MQTT_PASS\"@g" "$JSON_FILE"
    
    mkdir -p /opt/inverter-cli/bin
    ln -sf "$POLLER_BIN" /opt/inverter-cli/bin/inverter_poller
    sync
fi

export MQTT_HOST MQTT_USER MQTT_PASS MQTT_PORT

cd "$SCRIPTS_DIR"
echo "Iniciando procesos en $PWD..."

# Ejecutar primer volcado
/bin/bash ./mqtt-init.sh

# Mantener procesos en segundo plano
watch -n 300 /bin/bash ./mqtt-init.sh > /dev/null 2>&1 &
/bin/bash ./mqtt-subscriber.sh &

# Bucle principal de envío de datos
watch -n 30 /bin/bash ./mqtt-push.sh
