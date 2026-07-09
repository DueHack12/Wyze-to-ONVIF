# RTSP to ONVIF for UniFi Protect (Home Assistant add-on)

Local add-on wrapping [dlo747/RTSP-to-ONVIF-Unifi-Protect](https://github.com/dlo747/RTSP-to-ONVIF-Unifi-Protect):
exposes RTSP streams (e.g. from docker-wyze-bridge) as virtual ONVIF cameras,
each with its own MAC and DHCP IP, so UniFi Protect can adopt them as
third-party cameras.

## Install

1. Copy this whole `rtsp_to_onvif` folder to the `/addons` share of your
   Home Assistant box (use the Samba share or SSH add-on: the folder must end
   up as `/addons/rtsp_to_onvif/`).
2. In Home Assistant: **Settings → Add-ons → Add-on Store → ⋮ → Check for
   updates** (or reload the page). The add-on appears under **Local add-ons**.
3. Install it, fill in the **Configuration** tab, and start it.

Full configuration reference and UniFi Protect adoption steps are in the
add-on's **Documentation** tab (DOCS.md).
