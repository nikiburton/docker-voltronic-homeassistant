#!/bin/bash
export TERM=xterm

CONFIG_PATH=/data/options.json

# Leer configuración de HA
MQTT_HOST=$(jq --raw-output '.mqtt_host' $CONFIG_PATH)
MQTT_USER=$(jq --raw-output '.mqtt_user' $CONFIG_PATH)
MQTT_PASS=$(jq --raw-output '.mqtt_password' $CONFIG_PATH)
MQTT_PORT=$(jq --raw-output '.mqtt_port' $CONFIG_PATH)

# Buscar dónde está realmente el mqtt.json
JSON_FILE=$(find /opt -name "mqtt.json" | head -n 1)

if [ -f "$JSON_FILE" ]; then
    echo "Configurando $JSON_FILE con host: $MQTT_HOST"
    # Parchear el archivo
    sed -i "s@\[HA_MQTT_IP\]@$MQTT_HOST@g" "$JSON_FILE"
    sed -i "s@\"server\": \".*\"@\"server\": \"$MQTT_HOST\"@g" "$JSON_FILE"
    sed -i "s@\"port\": \".*\"@\"port\": \"$MQTT_PORT\"@g" "$JSON_FILE"
    sed -i "s@\"username\": \".*\"@\"username\": \"$MQTT_USER\"@g" "$JSON_FILE"
    sed -i "s@\"password\": \".*\"@\"password\": \"$MQTT_PASS\"@g" "$JSON_FILE"
else
    echo "ERROR: No se encontró mqtt.json en /opt"
fi

# Exportar variables para que los otros scripts las vean directamente
export MQTT_HOST MQTT_USER MQTT_PASS MQTT_PORT

# Lanzar los scripts originales (usando rutas relativas al archivo encontrado)
BASE_DIR=$(dirname "$JSON_FILE")
watch -n 300 "$BASE_DIR/mqtt-init.sh" > /dev/null 2>&1 &
"$BASE_DIR/mqtt-subscriber.sh" &
watch -n 30 "$BASE_DIR/mqtt-push.sh" > /dev/null 2>&1
