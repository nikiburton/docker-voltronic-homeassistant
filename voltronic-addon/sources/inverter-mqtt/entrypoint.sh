#!/bin/bash
export TERM=xterm

echo "--- [DEBUG] ENTRYPOINT MODIFICADO PARA DEBUG ---"
echo "--- LECTURA ÚNICA $(date) ---"

# Verificación rápida de que el cable responde
echo "Respuesta cruda del inversor:"
timeout 3s cat "$DEVICE" | xxd | head -n 5

echo "Ejecutando poller en modo debug (-d -1)..."
# Ejecutamos poller en debug
$POLLER_BIN -d -1 -c "$CONF_FILE"

echo "--- FIN DE DEBUG ---"
echo "Si todo funciona, recuerda restaurar el bucle infinito para HA."
