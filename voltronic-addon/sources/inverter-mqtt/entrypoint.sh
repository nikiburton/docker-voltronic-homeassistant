#!/usr/bin/with-contenv bash
set -e

echo "--- DETALLE DE DISPOSITIVOS USB ---"
lsusb
echo "------------------------------------"

CONFIG_PATH=/data/options.json
DEVICE=$(jq -r '.device' $CONFIG_PATH)
POLLER_BIN="/opt/inverter-cli/inverter_poller"

# --- LIBERACIÓN DEL DISPOSITIVO (SOLUCIÓN AL SECUESTRO) ---
echo "Intentando liberar $DEVICE del driver usbhid..."
for dev in /sys/bus/usb/drivers/usbhid/*-*:*; do
    if [ -e "$dev" ]; then
        echo "Desvinculando $(basename $dev)..."
        echo $(basename $dev) > /sys/bus/usb/drivers/usbhid/unbind || true
    fi
done

# Comprobación de existencia
if [ ! -e "$DEVICE" ]; then
    echo "ERROR: Dispositivo $DEVICE no existe"
    exit 1
fi

# Verificar dependencias del binario (por si el errno=2 es por una lib faltante)
echo "Verificando dependencias del poller..."
ldd "$POLLER_BIN" || echo "Aviso: No se pudo ejecutar ldd"

# Parchear MQTT JSON
if [ -f "$JSON_FILE" ]; then
    echo "Configurando $JSON_FILE..."
    sed -i "s@\"server\": \".*\"@\"server\": \"$MQTT_HOST\"@g" "$JSON_FILE"
    sed -i "s@\"port\": \".*\"@\"port\": \"$MQTT_PORT\"@g" "$JSON_FILE"
    sed -i "s@\"username\": \".*\"@\"username\": \"$MQTT_USER\"@g" "$JSON_FILE"
    sed -i "s@\"password\": \".*\"@\"password\": \"$MQTT_PASS\"@g" "$JSON_FILE"

    mkdir -p /opt/inverter-cli/bin
    ln -sf "$POLLER_BIN" /opt/inverter-cli/bin/inverter_poller
fi

cd "$SCRIPTS_DIR"

echo "Prueba directa de lectura HID..."
# Aseguramos permisos de ejecución y lanzamos
chmod +x "$POLLER_BIN"
"$POLLER_BIN" -d -p "$DEVICE"

# Iniciar procesos de MQTT
echo "Iniciando procesos..."
/bin/bash ./mqtt-init.sh
watch -n 300 /bin/bash ./mqtt-init.sh > /dev/null 2>&1 &
/bin/bash ./mqtt-subscriber.sh &

# Mantener loop de push
exec watch -n 30 /bin/bash ./mqtt-push.sh
