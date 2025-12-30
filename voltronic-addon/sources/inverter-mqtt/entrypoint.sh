#!/usr/bin/with-contenv bash
set -e

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

# 1. LIBERACIÓN DEL DISPOSITIVO (Crucial para HAOS)
echo "Intentando liberar $DEVICE del driver usbhid..."
# Intentamos remontar /sys como RW por si acaso
mount -o remount,rw /sys 2>/dev/null || true

for dev in /sys/bus/usb/drivers/usbhid/*:*; do
    if [ -e "$dev" ]; then
        echo "Desvinculando $(basename $dev)..."
        echo "$(basename $dev)" > /sys/bus/usb/drivers/usbhid/unbind || echo "Aviso: No se pudo desvincular $(basename $dev)"
    fi
done

# 2. Comprobación del dispositivo
if [ ! -e "$DEVICE" ]; then
    echo "ERROR: Dispositivo $DEVICE no existe"
    ls -l /dev/hidraw* || echo "No hay dispositivos hidraw disponibles"
    exit 1
fi

# 3. Configuración de MQTT JSON
if [ -f "$JSON_FILE" ]; then
    echo "Configurando $JSON_FILE..."
    sed -i "s@\"server\": \".*\"@\"server\": \"$MQTT_HOST\"@g" "$JSON_FILE"
    sed -i "s@\"port\": \".*\"@\"port\": \"$MQTT_PORT\"@g" "$JSON_FILE"
    sed -i "s@\"username\": \".*\"@\"username\": \"$MQTT_USER\"@g" "$JSON_FILE"
    sed -i "s@\"password\": \".*\"@\"password\": \"$MQTT_PASS\"@g" "$JSON_FILE"
fi

# 4. PREPARACIÓN DEL INVERTER.CONF (Solución al errno=2)
cd "$SCRIPTS_DIR"
if [ -f "$CONF_FILE" ]; then
    echo "Actualizando $CONF_FILE con el dispositivo $DEVICE..."
    sed -i "s|^device=.*|device=$DEVICE|" "$CONF_FILE"
    # Copiamos el config a rutas alternativas donde el poller suele buscar
    cp "$CONF_FILE" /usr/bin/inverter.conf
    cp "$CONF_FILE" /etc/inverter.conf
else
    echo "ERROR: No se encuentra el archivo $CONF_FILE"
fi

### eliminar cuando se ajuste en el inverter.conf
sed -i "s|^qpiri=.*|qpiri=106|" /opt/inverter-mqtt/inverter.conf
sed -i "s|^qpigs=.*|qpigs=110|" /opt/inverter-mqtt/inverter.conf
sed -i "s|^qpiws=.*|qpiws=36|" /opt/inverter-mqtt/inverter.conf
### eliminar cuando se ajuste en el inverter.conf

# 5. EJECUCIÓN CON DIAGNÓSTICO
echo "Prueba directa de lectura HID con STRACE..."
chmod +x "$POLLER_BIN"

# Usamos strace para ver exactamente qué archivo falla si el errno=2 persiste
strace -f -e trace=open,openat "$POLLER_BIN" -d 2>&1 | grep -E "inverter\.conf|hidraw|open" || {
    echo "El poller se ha detenido. Revisa los mensajes de openat arriba."
}

# 6. Iniciar procesos de MQTT (solo si el poller no bloquea el script)
echo "Iniciando procesos de fondo..."
/bin/bash ./mqtt-init.sh
watch -n 300 /bin/bash ./mqtt-init.sh > /dev/null 2>&1 &
/bin/bash ./mqtt-subscriber.sh &

# Mantener loop de push
echo "Ejecutando loop de datos..."
exec watch -n 30 /bin/bash ./mqtt-push.sh
