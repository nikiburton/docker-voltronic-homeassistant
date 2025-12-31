#!/usr/bin/with-contenv bash
# 1. ELIMINAR O COMENTAR set -e
# set -e  <-- ESTO ES LO QUE DETIENE EL ADDON. Mejor quitarlo.

ls -l /sys/bus/usb/drivers/usbhid/unbind

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

mount -o remount,rw /sys 2>/dev/null || true

echo "--- [INICIO] LIBERACIÓN QUIRÚRGICA CON TEE ---"
HID_NAME=$(basename "$DEVICE")

# Buscamos el bus asociado
for dev in /sys/class/hidraw/$HID_NAME/device/driver/*:*; do
    if [ -e "$dev" ]; then
        BUS_ID=$(basename "$dev")
        echo "Intentando liberar el bus $BUS_ID asociado a $DEVICE..."
        
        # Usamos tee para forzar la escritura
        echo "$BUS_ID" | tee /sys/bus/usb/drivers/usbhid/unbind > /dev/null
        
        if [ $? -eq 0 ]; then
            echo "SUCESO: Bus $BUS_ID liberado correctamente."
        else
            echo "ERROR: tee no pudo escribir en unbind (permisos de sistema)."
        fi
    fi
done
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
  
  # 1. Intentamos limpiar el buffer por si hay basura
  timeout 2s cat "$DEVICE" > /dev/null 2>&1 || true
  
  # 2. Ejecutamos el poller con un timeout un poco más corto para no esperar tanto
  # Pero añadimos la bandera -v (si el binario la soporta) o más debug
  echo "Iniciando poller..."
  timeout 15s $POLLER_BIN -d -c "$CONF_FILE"
  
  if [ $? -eq 124 ]; then
      echo "TIMEOUT: El inversor no respondió tras 15 segundos."
      echo "RECOMENDACIÓN: El error de Read-only en unbind sigue bloqueando el puerto."
  fi

  echo "--- [ESPERA] 30s ---"
  sleep 30
done
