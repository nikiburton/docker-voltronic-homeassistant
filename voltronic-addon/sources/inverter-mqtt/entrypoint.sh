#!/usr/bin/with-contenv bash
set -e

echo "--- DEBUG INVERTER START ---"
echo "Detectando dispositivos USB..."
lsusb
echo "------------------------------------"

DEVICE=/dev/hidraw0
BIN="/opt/inverter-cli/inverter_poller"

# Verificar que el binario exista
if [ ! -x "$BIN" ]; then
    echo "ERROR: no se encuentra el binario $BIN"
    exit 1
fi

# Verificar que el dispositivo exista
if [ ! -e "$DEVICE" ]; then
    echo "ERROR: dispositivo $DEVICE no existe"
    ls -l /dev/hidraw*
    exit 1
fi

echo "Usando dispositivo HID: $DEVICE"
echo "BINARIO INVERTER DEBUG FIX"

# Leer QPIGS
echo "--- [LECTURA] QPIGS ---"
$BIN -d -p $DEVICE -r QPIGS || echo "Fallo al leer QPIGS"

# Leer QPIRI
echo "--- [LECTURA] QPIRI ---"
$BIN -d -p $DEVICE -r QPIRI || echo "Fallo al leer QPIRI"

# Leer QPIWS
echo "--- [LECTURA] QPIWS ---"
$BIN -d -p $DEVICE -r QPIWS || echo "Fallo al leer QPIWS"

echo "--- DEBUG INVERTER END ---"
sleep infinity
