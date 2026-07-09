#!/bin/sh
set -e

# Translate the add-on options (/data/options.json) into the onvif.yaml the
# upstream server expects. The result lives in /data so the MAC addresses and
# UUIDs the server generates and writes back survive restarts and rebuilds —
# UniFi Protect identifies cameras by MAC, so these must stay stable.
node /ha-config.js

CAMERA_COUNT=$(node -p "(require('/data/options.json').cameras || []).length")
if [ "$CAMERA_COUNT" = "0" ]; then
    echo "[run.sh] No cameras configured yet. Add cameras in the add-on Configuration tab and restart the add-on."
    exec tail -f /dev/null
fi

if [ "$(node -p "!!require('/data/options.json').debug")" = "true" ]; then
    export DEBUG=1
fi

cd /app
exec node main.js /data/onvif.yaml
