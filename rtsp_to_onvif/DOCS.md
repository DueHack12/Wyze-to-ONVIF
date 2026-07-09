# RTSP to ONVIF for UniFi Protect

Wraps [dlo747/RTSP-to-ONVIF-Unifi-Protect](https://github.com/dlo747/RTSP-to-ONVIF-Unifi-Protect)
as a Home Assistant add-on. Each configured camera becomes a virtual ONVIF
device with its own MAC address and DHCP-assigned IP on your LAN, adoptable
by UniFi Protect as a third-party camera.

## Requirements

- **Ethernet.** The add-on creates one macvlan interface per camera on the
  host's network interface. This does not work over Wi-Fi.
- Home Assistant and your UniFi Protect console on the same L2 network/VLAN
  (or a route for ONVIF/RTSP traffic between them).
- UniFi Protect with third-party ONVIF camera support enabled
  (Settings → System → Advanced → Third-Party Cameras).
- An RTSP source, e.g. [docker-wyze-bridge](https://github.com/IDisposable/docker-wyze-bridge).

## Configuration

| Option | Description |
|---|---|
| `interface` | Host network interface to attach virtual camera interfaces to. On a Raspberry Pi this is usually `eth0` or `end0` — if you guess wrong, the add-on log lists the available names at startup. |
| `debug` | Verbose logging from the ONVIF server. |
| `cameras` | List of virtual cameras, see below. |

Per camera:

| Option | Required | Description |
|---|---|---|
| `name` | yes | Letters/digits only, must start with a letter. Shown in Protect. Changing it later resets the camera's generated MAC — Protect will see a new device. |
| `target_host` | yes | IP/hostname of the RTSP source (your wyze-bridge host). |
| `target_rtsp_port` | no | RTSP port of the source. Default `8554` (wyze-bridge default). |
| `target_snapshot_port` | no | HTTP port of the source for snapshots. Default `5000` (wyze-bridge Web-UI). |
| `rtsp_path` | yes | Stream path on the source, e.g. `/front-door` for wyze-bridge camera `front-door`. |
| `snapshot_path` | no | Snapshot path on the source. Defaults to `/snapshot/<name>.jpg`. Snapshots are not fully working upstream yet. |
| `width`, `height`, `framerate`, `bitrate` | yes | Must match what the source stream actually delivers (bitrate in kb/s). Protect uses these as the advertised stream capabilities. |
| `server_port` | no | ONVIF HTTP port on the camera's virtual IP. Default `8081`, safe to share between cameras. |
| `rtsp_proxy_port` / `snapshot_proxy_port` | no | Local proxy ports. Auto-assigned uniquely per camera (`18554+n` / `18080+n`); only set them to resolve a port conflict. |
| `mac` / `uuid` | no | Auto-generated on first start and persisted in `/data/onvif.yaml`. Only set to pin values explicitly. |

### Example (two Wyze cams via wyze-bridge at 192.168.1.20)

```yaml
interface: eth0
debug: false
cameras:
  - name: FrontDoor
    target_host: 192.168.1.20
    rtsp_path: /front-door
    width: 1920
    height: 1080
    framerate: 20
    bitrate: 2048
  - name: Garage
    target_host: 192.168.1.20
    rtsp_path: /garage
    width: 1920
    height: 1080
    framerate: 20
    bitrate: 2048
```

## Adopting in UniFi Protect

1. Start the add-on and open its log. For each camera you should see the
   macvlan interface being created (`NET_CONF: ADD - rtsp2onvif_N`), a DHCP
   lease, and `HTTP listening on <ip>:8081`. The virtual cameras appear in
   your UniFi client list with MAC prefix `1A:11:B0`.
2. In Protect, the cameras should be discovered automatically (WS-Discovery).
   If not, add them manually by IP with the ONVIF port (default `8081`).
   Third-party ONVIF cameras in Protect don't require credentials from this
   proxy; if prompted, any username/password works.

## Notes and limitations

- Streams must be H.264 (wyze-bridge outputs H.264 by default). PTZ, audio
  playback, and smart detections are not available for third-party cameras
  in Protect; snapshots and timeline scrubbing are hit-or-miss upstream.
- Generated MACs/UUIDs live in `/data/onvif.yaml`. Uninstalling the add-on
  deletes `/data`, and Protect will then see brand-new cameras on reinstall.
- If a camera fails with `Failed to find IP address for MAC address ...`,
  the macvlan interface didn't get created or didn't get a DHCP lease —
  check the `interface` option, that the Pi is on Ethernet, and that your
  DHCP server has free leases.
- After a host reboot the interfaces are recreated with the same persisted
  MACs, so DHCP hands back the same IPs (assuming your DHCP server honors
  lease reuse — fixed IP reservations in your router make this bulletproof).
