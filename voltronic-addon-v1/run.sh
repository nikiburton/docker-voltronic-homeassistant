#!/bin/bash
set -e

CONFIG_PATH=/data/options.json

DEVICE=$(jq -r '.device' $CONFIG_PATH)
MQTT_HOST=$(jq -r '.mqtt_host' $CONFIG_PATH)
MQTT_USER=$(jq -r '.mqtt_user' $CONFIG_PATH)
MQTT_PASS=$(jq -r '.mqtt_password' $CONFIG_PATH)
MQTT_PORT=$(jq -r '.mqtt_port' $CONFIG_PATH)

echo "Usando dispositivo: $DEVICE"

# Verificar que el dispositivo existe
if [ ! -e "$DEVICE" ]; then
    echo "ERROR: no existe el dispositivo $DEVICE"
    exit 1
fi

# Ejecutar poller (ajustar según tu binario)
/opt/inverter-mqtt/inverter_poller -d -p "$DEVICE" &

