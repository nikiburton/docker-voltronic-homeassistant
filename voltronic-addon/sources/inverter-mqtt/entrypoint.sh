#!/bin/bash
export TERM=xterm

# DIAGNÓSTICO: Ver qué hay en el sistema
echo "--- Listado de archivos en /opt ---"
ls -R /opt
echo "----------------------------------"

CONFIG_PATH=/data/options.json

# Leer configuración de HA
MQTT_HOST=$(jq --raw-output '.mqtt_host' $CONFIG_PATH)
MQTT_USER=$(jq --raw-output '.mqtt_user' $CONFIG_PATH)
MQTT_PASS=$(jq --raw-output '.mqtt_password' $CONFIG_PATH)
MQTT_PORT=$(jq --raw-output '.mqtt_port' $CONFIG_PATH)

# Buscar el archivo con una ruta más amplia
JSON_FILE=$(find / -name "mqtt.json" 2>/dev/null | grep -v "var/lib/docker" | head -n 1)

if [ -n "$JSON_FILE" ] && [ -f "$JSON_FILE" ]; then
    echo "¡Encontrado! Configurando $JSON_FILE"
    sed -i "s@\[HA_MQTT_IP\]@$MQTT_HOST@g" "$JSON_FILE"
    sed -i "s@\"server\": \".*\"@\"server\": \"$MQTT_HOST\"@g" "$JSON_FILE"
    sed -i "s@\"port\": \".*\"@\"port\": \"$MQTT_PORT\"@g" "$JSON_FILE"
    sed -i "s@\"username\": \".*\"@\"username\": \"$MQTT_USER\"@g" "$JSON_FILE"
    sed -i "s@\"password\": \".*\"@\"password\": \"$MQTT_PASS\"@g" "$JSON_FILE"
    sync
    
    # Exportar variables
    export MQTT_HOST MQTT_USER MQTT_PASS MQTT_PORT
    BASE_DIR=$(dirname "$JSON_FILE")
    cd "$BASE_DIR"
    
    echo "Iniciando procesos en $BASE_DIR..."
    /bin/bash ./mqtt-init.sh
    sleep 2
    watch -n 300 /bin/bash ./mqtt-init.sh > /dev/null 2>&1 &
    /bin/bash ./mqtt-subscriber.sh &
    watch -n 30 /bin/bash ./mqtt-push.sh
else
    echo "ERROR CRÍTICO: No se encontró mqtt.json en ningún lugar del contenedor."
    exit 1
fi
