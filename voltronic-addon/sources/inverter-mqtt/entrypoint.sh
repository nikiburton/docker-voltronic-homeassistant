#!/usr/bin/with-contenv bash
# 1. ELIMINAR O COMENTAR set -e
# set -e  <-- ESTO ES LO QUE DETIENE EL ADDON. Mejor quitarlo.

echo "--- DETALLE DE DISPOSITIVOS USB ---"
lsusb
echo "------------------------------------"

CONFIG_PATH=/data/options.json
MQTT_HOST=$(jq -r '.mqtt_host' $CONFIG_PATH)
MQTT_USER=$(jq -r '.mqtt_user' $CONFIG_PATH)
MQTT_PASS=$(jq -r '.mqtt_password' $CONFIG_PATH)
MQTT_PORT=$(jq -r '.mqtt_port' $CONFIG_PATH)
DEVICE=$(jq -r '.device' $CONFIG_PATH)

JSON_FILE="/opt/inverter-mqtt/mqtt.json"
SCRIPTS_DIR="/opt/inverter-mqtt"
POLLER_BIN="/usr/bin/inverter_poller"
CONF_FILE="/opt/inverter-mqtt/inverter.conf"

echo "Usando dispositivo HID: $DEVICE"

echo "--- [INICIO] LIBERACIÓN DE DISPOSITIVO USB ---"
# Intentamos liberar CUALQUIER dispositivo HID para que el poller pueda acceder
if [ -d /sys/bus/usb/drivers/usbhid ]; then
    for dev in /sys/bus/usb/drivers/usbhid/*:*; do
        if [ -e "$dev" ]; then
            echo "Liberando dispositivo: $(basename $dev)"
            echo "$(basename $dev)" > /sys/bus/usb/drivers/usbhid/unbind 2>/dev/null || true
        fi
    done
fi
echo "--- [FIN] LIBERACIÓN COMPLETADA ---"

# 2. Comprobación del dispositivo
if [ ! -e "$DEVICE" ]; then
    echo "ERROR: Dispositivo $DEVICE no existe"
    ls -l /dev/hidraw* || echo "No hay dispositivos hidraw disponibles"
    # No salimos con exit 1 para que el addon no entre en bucle de reinicio
fi

# 3. Configuración de MQTT JSON
if [ -f "$JSON_FILE" ]; then
    echo "Configurando $JSON_FILE..."
    sed -i "s@\"server\": \".*\"@\"server\": \"$MQTT_HOST\"@g" "$JSON_FILE"
    sed -i "s@\"port\": \".*\"@\"port\": \"$MQTT_PORT\"@g" "$JSON_FILE"
    sed -i "s@\"username\": \".*\"@\"username\": \"$MQTT_USER\"@g" "$JSON_FILE"
    sed -i "s@\"password\": \".*\"@\"password\": \"$MQTT_PASS\"@g" "$JSON_FILE"
fi

# 4. PREPARACIÓN DEL INVERTER.CONF
cd "$SCRIPTS_DIR"
if [ -f "$CONF_FILE" ]; then
    echo "Actualizando $CONF_FILE con el dispositivo $DEVICE..."
    sed -i "s|^device=.*|device=$DEVICE|" "$CONF_FILE"
    # Copiamos a la ruta por defecto donde el binario suele buscar
    cp "$CONF_FILE" /etc/inverter.conf
fi

chmod +x "$POLLER_BIN"
chmod +x ./*.sh

echo "Iniciando procesos de MQTT..."
/bin/bash ./mqtt-init.sh &
sleep 2
/bin/bash ./mqtt-subscriber.sh &

# 5. EL BUCLE DEFINITIVO
while true; do
  echo "--- [LECTURA] $(date) ---"
  
  # Añadimos un echo justo antes de disparar el binario
  echo "Llamando al binario poller con config: $CONF_FILE"
  
  # Ejecutamos con timeout de 20s para que no se congele el addon
  timeout 20s $POLLER_BIN -d -c "$CONF_FILE" || echo "Error o Timeout en la comunicación"
  
  echo "--- [ENVÍO MQTT] ---"
  /bin/bash ./mqtt-push.sh || true
  
  echo "--- [ESPERA] 30s ---"
  sleep 30
done
