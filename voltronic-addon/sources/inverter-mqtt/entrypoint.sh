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

# --- CONFIGURACIÓN DE PERMISOS PARA HID ---
echo "Forzando creación de nodo HID..."
# Esto crea el archivo que el programa dice que no encuentra
mknod -m 666 /dev/hidraw0 c 242 0 2>/dev/null
# Damos permisos a los buses
chmod -R 777 /dev/bus/usb/
echo "Permisos aplicados."
# -------------------------------------------

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

echo "Haciendo prueba de lectura manual..."
# Aquí le pasamos el parámetro -p para decirle que use el hidraw
/opt/inverter-cli/inverter_poller -d -p /dev/hidraw0

# Bucle principal de envío de datos
watch -n 30 /bin/bash ./mqtt-push.sh
