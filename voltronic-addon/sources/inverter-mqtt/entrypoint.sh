#!/usr/bin/with-contenv bash
set -e

echo "--- DETALLE DE DISPOSITIVOS USB ---"
lsusb
echo "------------------------------------"

# 1. Cargar variables de configuración
CONFIG_PATH=/data/options.json
MQTT_HOST=$(jq -r '.mqtt_host' $CONFIG_PATH)
MQTT_USER=$(jq -r '.mqtt_user' $CONFIG_PATH)
MQTT_PASS=$(jq -r '.mqtt_password' $CONFIG_PATH)
MQTT_PORT=$(jq -r '.mqtt_port' $CONFIG_PATH)
DEVICE=$(jq -r '.device' $CONFIG_PATH)

# Definir rutas fijas para evitar errores de "null directory"
JSON_FILE="/etc/inverter/mqtt.json"
SCRIPTS_DIR="/opt/inverter-mqtt"
POLLER_BIN="/opt/inverter-cli/inverter_poller"

echo "Usando dispositivo HID: $DEVICE"

# 2. LIBERACIÓN DEL DISPOSITIVO (Crucial para evitar el bloqueo del Kernel)
echo "Intentando liberar $DEVICE del driver usbhid..."
if [ -e /sys/bus/usb/drivers/usbhid/unbind ]; then
    for dev in /sys/bus/usb/drivers/usbhid/*:*; do
        if [ -e "$dev" ]; then
            echo "Desvinculando $(basename $dev)..."
            # Usamos sh -c para asegurar que la redirección funcione con permisos
            echo "$(basename $dev)" > /sys/bus/usb/drivers/usbhid/unbind || true
        fi
    done
else
    echo "AVISO: No se puede escribir en /sys. RECUERDA DESACTIVAR EL 'PROTECTION MODE' EN HA."
fi

# 3. Comprobación del dispositivo
if [ ! -e "$DEVICE" ]; then
    echo "ERROR: Dispositivo $DEVICE no existe"
    ls -l /dev/hidraw* || echo "No hay dispositivos hidraw disponibles"
    exit 1
fi

ls -l "$DEVICE"

# 4. Configuración de MQTT JSON
if [ -f "$JSON_FILE" ]; then
    echo "Configurando $JSON_FILE..."
    sed -i "s@\"server\": \".*\"@\"server\": \"$MQTT_HOST\"@g" "$JSON_FILE"
    sed -i "s@\"port\": \".*\"@\"port\": \"$MQTT_PORT\"@g" "$JSON_FILE"
    sed -i "s@\"username\": \".*\"@\"username\": \"$MQTT_USER\"@g" "$JSON_FILE"
    sed -i "s@\"password\": \".*\"@\"password\": \"$MQTT_PASS\"@g" "$JSON_FILE"

    mkdir -p /opt/inverter-cli/bin
    ln -sf "$POLLER_BIN" /opt/inverter-cli/bin/inverter_poller
fi

# 5. Ejecución
cd "$SCRIPTS_DIR" || { echo "ERROR: No se pudo entrar a $SCRIPTS_DIR"; exit 1; }

echo "Prueba directa de lectura HID..."
chmod +x "$POLLER_BIN"
"$POLLER_BIN" -d -p "$DEVICE" || {
    echo "ERROR: fallo acceso HID. Verifica permisos o si el dispositivo está ocupado."
    # No salimos aquí para intentar que el resto del addon funcione si es un error temporal
}

echo "Iniciando procesos de MQTT..."
/bin/bash ./mqtt-init.sh
watch -n 300 /bin/bash ./mqtt-init.sh > /dev/null 2>&1 &
/bin/bash ./mqtt-subscriber.sh &

# Mantener loop de push
echo "Ejecutando loop de datos..."
exec watch -n 30 /bin/bash ./mqtt-push.sh
