#!/usr/bin/with-contenv bash
# 1. ELIMINAR O COMENTAR set -e
set -e  <-- ESTO ES LO QUE DETIENE EL ADDON. Mejor quitarlo.

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
  echo "--- [1/3] INICIANDO COMUNICACIÓN ---"
  date
  
  # Usamos 'timeout' de Linux para que si el binario se cuelga, el script lo mate tras 15s
  # Esto evita que el addon se quede "mudo"
  if timeout 15s $POLLER_BIN -d -c "$CONF_FILE"; then
      echo "--- [2/3] LECTURA EXITOSA ---"
  else
      echo "--- [2/3] ERROR: El poller tardó demasiado o falló (Timeout) ---"
  fi
  
  echo "--- [3/3] INTENTANDO MQTT PUSH ---"
  if /bin/bash ./mqtt-push.sh; then
      echo "Datos enviados a MQTT correctamente."
  else
      echo "Fallo al enviar a MQTT."
  fi
  
  echo "--- [ESPERA] Ciclo terminado. Durmiendo 30s ---"
  sleep 30
done
