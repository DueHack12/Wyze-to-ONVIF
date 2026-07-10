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

# Remove virtual camera interfaces left over from a previous run (the
# container can die without a chance to clean up; stale interfaces keep
# ARP-replying on the LAN).
for IFACE in $(ip -o link show 2>/dev/null | awk -F': ' '{print $2}' | grep '^rtsp2onvif_' | cut -d@ -f1); do
    echo "[run.sh] Removing stale interface ${IFACE}"
    ip link del "${IFACE}" 2>/dev/null || true
done

# The macvlan camera interfaces share the host's L2. By default Linux answers
# ARP for ANY local IP on ANY interface (ARP flux), so the camera interfaces
# also answer for the host's own IP — UniFi then reports an IP address
# conflict and traffic to the host breaks. arp_ignore=1 restricts ARP replies
# to the interface that actually owns the address.
if ! sysctl -w net.ipv4.conf.all.arp_ignore=1 net.ipv4.conf.all.arp_announce=2 \
        net.ipv4.conf.default.arp_ignore=1 net.ipv4.conf.default.arp_announce=2; then
    echo "[run.sh] WARNING: could not set ARP sysctls (arp_ignore/arp_announce)."
    echo "[run.sh] Your router may report an IP address conflict for this host's IP."
fi

if [ "$(node -p "!!require('/data/options.json').debug")" = "true" ]; then
    export DEBUG=1
fi

cd /app
exec node main.js /data/onvif.yaml
