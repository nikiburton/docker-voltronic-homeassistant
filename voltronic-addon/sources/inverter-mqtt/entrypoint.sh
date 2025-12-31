#!/usr/bin/with-contenv bash

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

# 1. Intentar liberar el bus (aunque falle el unbind por Read-only, el '¡PUERTO VIVO!' manda)
mount -o remount,rw /sys 2>/dev/null || true
HID_NAME=$(basename "$DEVICE")
for dev in /sys/class/hidraw/$HID_NAME/device/driver/*:*; do
    if [ -e "$dev" ]; then
        BUS_ID=$(basename "$dev")
        echo "$BUS_ID" | tee /sys/bus/usb/drivers/usbhid/unbind > /dev/null 2>&1 || true
    fi
done

# 2. Reconstrucción estricta de inverter.conf
echo "Generando configuración técnica..."
printf "device=%s\n" "$DEVICE" > "$CONF_FILE"
printf "run_interval=30\n" >> "$CONF_FILE"
printf "timeout=2000\n" >> "$CONF_FILE"
printf "amperage_factor=1.0\n" >> "$CONF_FILE"
printf "watt_factor=1.01\n" >> "$CONF_FILE"
printf "qpiri_cmd=QPIRI\r\n" >> "$CONF_FILE"
printf "qpiri_reply_len=102\n" >> "$CONF_FILE"
printf "qpigs_cmd=QPIGS\r\n" >> "$CONF_FILE"
printf "qpigs_reply_len=110\n" >> "$CONF_FILE"
printf "qmod_reply_len=5\n" >> "$CONF_FILE"
printf "qpiws_reply_len=36\n" >> "$CONF_FILE"

cp "$CONF_FILE" /etc/inverter.conf

# 3. Debug visual del archivo
echo "--- [DEBUG] VERIFICANDO FINALES DE LINEA (^M es bueno) ---"
cat -A "$CONF_FILE" | grep "_cmd"
echo "--------------------------------------------------------"

# 4. Configuración MQTT
sed -i "s@\"server\": \".*\"@\"server\": \"$MQTT_HOST\"@g" "$JSON_FILE"
sed -i "s@\"port\": \".*\"@\"port\": \"$MQTT_PORT\"@g" "$JSON_FILE"
sed -i "s@\"username\": \".*\"@\"username\": \"$MQTT_USER\"@g" "$JSON_FILE"
sed -i "s@\"password\": \".*\"@\"password\": \"$MQTT_PASS\"@g" "$JSON_FILE"

cd "$SCRIPTS_DIR"
chmod +x "$POLLER_BIN"
chmod +x ./*.sh

echo "Iniciando procesos de MQTT..."
/bin/bash ./mqtt-init.sh &
sleep 2
/bin/bash ./mqtt-subscriber.sh &

# 5. Bucle de lectura
while true; do
  echo "--- [LECTURA] $(date) ---"
  
  # Verificación de hardware
  timeout 2s dd if="$DEVICE" bs=1 count=1 2>/dev/null | xxd && echo "¡PUERTO VIVO!" || echo "Puerto bloqueado"

  echo "Ejecutando poller con Debug..."
  # Usamos -d para ver qué responde el inversor exactamente
  timeout 15s $POLLER_BIN -d -c "$CONF_FILE"
  
  echo "--- [ENVÍO MQTT] ---"
  /bin/bash ./mqtt-push.sh || true
  
  echo "--- [ESPERA] 30s ---"
  sleep 30
done
