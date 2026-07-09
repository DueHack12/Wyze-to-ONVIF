ARG BUILD_FROM=node:22-alpine
FROM ${BUILD_FROM}

# dhclient is required to pull a DHCP lease for each virtual camera interface.
# HA Supervisor builds add-ons from its own ghcr.io/home-assistant/base image
# regardless of build_from in build.yaml, so Node/npm aren't guaranteed to be
# present from the FROM base — install them explicitly (no-op if already there).
RUN apk add --no-cache --repository=https://dl-cdn.alpinelinux.org/alpine/v3.20/main dhclient \
    && (command -v npm >/dev/null 2>&1 || apk add --no-cache --repository=https://dl-cdn.alpinelinux.org/alpine/v3.20/main nodejs npm)

ENV NODE_ENV=production
WORKDIR /app

# dlo747/RTSP-to-ONVIF-Unifi-Protect, pinned to main as of 2026-07-09
ARG UPSTREAM_SHA=fcdbcf9f624bd00c874bc00b6b5a07a77ec4f536
RUN wget -qO /tmp/upstream.tar.gz "https://github.com/dlo747/RTSP-to-ONVIF-Unifi-Protect/archive/${UPSTREAM_SHA}.tar.gz" \
    && tar -xzf /tmp/upstream.tar.gz -C /app --strip-components=1 \
    && rm /tmp/upstream.tar.gz

RUN npm ci --omit=dev --silent

COPY ha-config.js /ha-config.js
COPY run.sh /run.sh
RUN chmod +x /run.sh

CMD ["/run.sh"]
