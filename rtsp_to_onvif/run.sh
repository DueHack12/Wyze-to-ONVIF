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

# The macvlan camera interfaces share the host's L2 network. By default Linux
# answers ARP for ANY local IP out of ANY interface (ARP flux), so the camera
# interfaces also reply to ARP-who-has for the HOST's own IP. UniFi then sees
# the host IP claimed by several MACs and raises an "IP address conflict",
# which can disrupt traffic to the host (and to docker-wyze-bridge).
#
# The usual fix is the arp_ignore sysctl, but a host-network container gets a
# read-only /proc/sys (Docker won't let a container reconfigure the host's
# shared netns), so `sysctl -w` fails no matter how privileged we are. Instead
# we drop the bogus ARP replies with arptables, which only needs NET_ADMIN.
#
# The rule matches the future camera interfaces by name wildcard, so it can be
# installed here (before the upstream server creates them). It lives in the
# shared host netns and persists across container restarts, so delete any prior
# copy first to stay idempotent.
HOST_IFACE=$(node -p "require('/data/options.json').interface" 2>/dev/null)
HOST_IP=$(ip -4 -o addr show "${HOST_IFACE}" 2>/dev/null | awk '{print $4}' | cut -d/ -f1 | head -n1)
if command -v arptables >/dev/null 2>&1 && [ -n "${HOST_IP}" ]; then
    arptables -D OUTPUT --source-ip "${HOST_IP}" --out-interface 'rtsp2onvif_+' -j DROP 2>/dev/null || true
    if arptables -A OUTPUT --source-ip "${HOST_IP}" --out-interface 'rtsp2onvif_+' -j DROP; then
        echo "[run.sh] arptables: camera interfaces will not answer ARP for host IP ${HOST_IP}"
    else
        echo "[run.sh] WARNING: failed to add arptables anti-ARP-flux rule."
        echo "[run.sh] UniFi may report an IP address conflict for ${HOST_IP}."
    fi
else
    echo "[run.sh] WARNING: arptables unavailable or host IP unknown (iface='${HOST_IFACE}')."
    echo "[run.sh] Cannot prevent ARP flux; UniFi may report an IP conflict for the host IP."
fi

if [ "$(node -p "!!require('/data/options.json').debug")" = "true" ]; then
    export DEBUG=1
fi

cd /app
exec node main.js /data/onvif.yaml
