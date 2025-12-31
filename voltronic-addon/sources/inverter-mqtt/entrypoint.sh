#!/usr/bin/with-contenv bash

echo "--- [INICIO] ARRANCANDO VOLTRONIC ADDO-ON ---"

# 1. CARGA DE CONFIGURACIÓN
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

# 2. INTENTO DE LIBERACIÓN DE BUS
echo "--- [PASO 1] LIBERANDO HARDWARE ---"
HID_NAME=$(basename "$DEVICE")
for dev in /sys/class/hidraw/$HID_NAME/device/driver/*:*; do
    if [ -e "$dev" ]; then
        BUS_ID=$(basename "$dev")
        echo "Liberando Bus ID: $BUS_ID"
        echo "$BUS_ID" > /sys/bus/usb/drivers/usbhid/unbind 2>/dev/null || true
    fi
done
chmod 666 "$DEVICE" 2>/dev/null || true

# 3. GENERACIÓN DE CONFIGURACIÓN (Sin CRC manual, dejando que el binario lo calcule)
echo "--- [PASO 2] GENERANDO CONFIGURACIÓN LIMPIA ---"
printf "device=%s\n" "$DEVICE" > "$CONF_FILE"
printf "run_interval=30\n" >> "$CONF_FILE"
printf "timeout=5000\n" >> "$CONF_FILE"
printf "amperage_factor=1.0\n" >> "$CONF_FILE"
printf "watt_factor=1.01\n" >> "$CONF_FILE"

# Comandos limpios. Si el binario es el correcto, él añadirá el CRC y el \r
printf "qpiri_cmd=QPIRI\n" >> "$CONF_FILE"
printf "qpiri_reply_len=102\n" >> "$CONF_FILE"
printf "qpigs_cmd=QPIGS\n" >> "$CONF_FILE"
printf "qpigs_reply_len=110\n" >> "$CONF_FILE"
printf "qmod_reply_len=5\n" >> "$CONF_FILE"
printf "qpiws_reply_len=36\n" >> "$CONF_FILE"

cp "$CONF_FILE" /etc/inverter.conf

# 4. CONFIGURACIÓN MQTT
echo "--- [PASO 3] CONFIGURANDO MQTT ---"
sed -i "s@\"server\": \".*\"@\"server\": \"$MQTT_HOST\"@g" "$JSON_FILE"
sed -i "s@\"port\": \".*\"@\"port\": \"$MQTT_PORT\"@g" "$JSON_FILE"
sed -i "s@\"username\": \".*\"@\"username\": \"$MQTT_USER\"@g" "$JSON_FILE"
sed -i "s@\"password\": \".*\"@\"password\": \"$MQTT_PASS\"@g" "$JSON_FILE"

cd "$SCRIPTS_DIR"
chmod +x "$POLLER_BIN"
chmod +x ./*.sh

echo "Iniciando servicios MQTT..."
/bin/bash ./mqtt-init.sh &
/bin/bash ./mqtt-subscriber.sh &

# 5. BUCLE DE LECTURA
echo "--- [PASO 4] INICIANDO BUCLE DE LECTURA ---"
while true; do
  echo "--- LECTURA $(date) ---"
  
  # Verificación de respuesta cruda (debe empezar por '(' )
  echo "Respuesta cruda detectada:"
  timeout 2s cat "$DEVICE" | xxd | head -n 1 || echo "Sin respuesta en el puerto"

  echo "Ejecutando poller en modo debug..."
  # Usamos -d para ver cómo construye el binario el comando internamente
  timeout 15s $POLLER_BIN -d -c "$CONF_FILE"
  
  if [ $? -eq 124 ]; then
    echo "ERROR: Timeout de 15s. El binario no recibe datos válidos."
  fi

  echo "Enviando a MQTT..."
  /bin/bash ./mqtt-push.sh || true
  
  echo "Esperando 30 segundos..."
  sleep 30
done
