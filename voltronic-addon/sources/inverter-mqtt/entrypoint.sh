#!/bin/bash
export TERM=xterm

CONFIG_PATH=/data/options.json

# 1. Leer configuración de HA
MQTT_HOST=$(jq --raw-output '.mqtt_host' $CONFIG_PATH)
MQTT_USER=$(jq --raw-output '.mqtt_user' $CONFIG_PATH)
MQTT_PASS=$(jq --raw-output '.mqtt_password' $CONFIG_PATH)
MQTT_PORT=$(jq --raw-output '.mqtt_port' $CONFIG_PATH)

# 2. Rutas fijas confirmadas por el log
JSON_FILE="/etc/inverter/mqtt.json"
SCRIPTS_DIR="/opt/inverter-mqtt"

echo "Configurando $JSON_FILE con host: $MQTT_HOST"

# 3. Parchear el JSON (donde el programa busca la config)
if [ -f "$JSON_FILE" ]; then
    sed -i "s@\[HA_MQTT_IP\]@$MQTT_HOST@g" "$JSON_FILE"
    sed -i "s@\"server\": \".*\"@\"server\": \"$MQTT_HOST\"@g" "$JSON_FILE"
    sed -i "s@\"port\": \".*\"@\"port\": \"$MQTT_PORT\"@g" "$JSON_FILE"
    sed -i "s@\"username\": \".*\"@\"username\": \"$MQTT_USER\"@g" "$JSON_FILE"
    sed -i "s@\"password\": \".*\"@\"password\": \"$MQTT_PASS\"@g" "$JSON_FILE"
    sync
else
    echo "ERROR: $JSON_FILE no encontrado."
    exit 1
fi

# 4. Exportar variables para los scripts
export MQTT_HOST MQTT_USER MQTT_PASS MQTT_PORT

# 5. Ejecutar los scripts desde su carpeta real
cd "$SCRIPTS_DIR"
echo "Iniciando procesos en $PWD..."

# Lanzar registro inicial
/bin/bash ./mqtt-init.sh
sleep 2

# Lanzar procesos en segundo plano
watch -n 300 /bin/bash ./mqtt-init.sh > /dev/null 2>&1 &
/bin/bash ./mqtt-subscriber.sh &

# Proceso principal
watch -n 30 /bin/bash ./mqtt-push.sh
