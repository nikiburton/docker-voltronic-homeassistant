#!/bin/bash
export TERM=xterm

# --- NUEVA SECCIÓN DE CONFIGURACIÓN ---
# Leer configuración de Home Assistant (usando jq para parsear el archivo options.json)
CONFIG_PATH=/data/options.json

MQTT_HOST=$(jq --raw-output '.mqtt_host' $CONFIG_PATH)
MQTT_USER=$(jq --raw-output '.mqtt_user' $CONFIG_PATH)
MQTT_PASS=$(jq --raw-output '.mqtt_password' $CONFIG_PATH)
MQTT_PORT=$(jq --raw-output '.mqtt_port' $CONFIG_PATH)

echo "Configurando mqtt.json con los datos de la interfaz..."

# Sustituir los valores en el archivo mqtt.json
# Usamos @ como delimitador en sed por si la contraseña tiene caracteres raros
sed -i "s@\[HA_MQTT_IP\]@$MQTT_HOST@g" /opt/inverter-mqtt/mqtt.json
sed -i "s@\"port\": \".*\"@\"port\": \"$MQTT_PORT\"@g" /opt/inverter-mqtt/mqtt.json
sed -i "s@\"username\": \".*\"@\"username\": \"$MQTT_USER\"@g" /opt/inverter-mqtt/mqtt.json
sed -i "s@\"password\": \".*\"@\"password\": \"$MQTT_PASS\"@g" /opt/inverter-mqtt/mqtt.json

echo "MQTT configurado hacia el host: $MQTT_HOST"
# ---------------------------------------

# Init the mqtt server for the first time, then every 5 minutes
watch -n 300 /opt/inverter-mqtt/mqtt-init.sh > /dev/null 2>&1 &

# Run the MQTT Subscriber process
/opt/inverter-mqtt/mqtt-subscriber.sh &

# Execute exactly every 30 seconds
watch -n 30 /opt/inverter-mqtt/mqtt-push.sh > /dev/null 2>&1
