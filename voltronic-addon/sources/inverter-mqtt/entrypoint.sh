#!/bin/bash
export TERM=xterm

# Variables con valores por defecto
DEVICE="${DEVICE:-/dev/hidraw0}"
POLLER_BIN="${POLLER_BIN:-/usr/bin/inverter_poller}"
CONF_FILE="${CONF_FILE:-/opt/inverter/inverter.conf}"

echo "--- [DEBUG] ENTRYPOINT MODIFICADO PARA DEBUG ---"
echo "--- LECTURA ÚNICA $(date) ---"

# Verificación rápida de que el cable responde
if [ -e "$DEVICE" ]; then
    echo "Respuesta cruda del inversor:"
    timeout 3s cat "$DEVICE" | xxd | head -n 5
else
    echo "ERROR: Dispositivo $DEVICE no encontrado"
fi

echo "Ejecutando poller en modo debug (-d -1)..."
#"$POLLER_BIN" -d -1 -c "$CONF_FILE" # para ver buffers y offsets
"$POLLER_BIN" -v -c "$CONF_FILE" # para ver los datos parseados

echo "--- FIN DE DEBUG ---"
