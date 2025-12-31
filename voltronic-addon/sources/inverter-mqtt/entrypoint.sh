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
# ... (mantén todo lo anterior igual hasta llegar al bucle) ...

while true; do
  echo "--- [LECTURA] $(date) ---"
  
  # PRUEBA DE VIDA DEL PUERTO
  # Intentamos forzar permisos sobre el dispositivo directamente
  chmod 666 "$DEVICE" 2>/dev/null || true
  
  echo "Verificando si hay datos en el puerto..."
  # Intentamos leer 1 solo byte. Si esto NO da timeout, el puerto está abierto.
  timeout 3s dd if="$DEVICE" bs=1 count=1 2>/dev/null | xxd && echo "¡PUERTO VIVO!" || echo "Puerto bloqueado o sin datos."

  echo "Ejecutando poller..."
  # Usaremos el binario pero sin el flag -d (debug) para ver si cambia el comportamiento
  # A veces el modo debug llena el buffer y lo bloquea
  timeout 15s $POLLER_BIN -c "$CONF_FILE"
  
  if [ $? -eq 124 ]; then
    echo "Aviso: El poller ha agotado el tiempo. El driver del sistema sigue interfiriendo."
    echo "Intentando 'limpieza' de emergencia..."
    # Un pequeño truco: enviar un pulso nulo al dispositivo
    echo -e "\n" > "$DEVICE" 2>/dev/null || true
  fi

  echo "--- [ENVÍO MQTT] ---"
  /bin/bash ./mqtt-push.sh || true

  echo "--- [ESPERA] 30s ---"
  sleep 30
done
