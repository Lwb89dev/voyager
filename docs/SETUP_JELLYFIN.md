# Jellyfin

Jellyfin (GPL v2) is a full media server — music, films, television. If you
already run one, Voyager can use its music library without a second server.

## Run the server

```bash
docker run -d \
  --name jellyfin \
  --restart unless-stopped \
  -p 8096:8096 \
  -v jellyfin_config:/config \
  -v jellyfin_cache:/cache \
  -v /path/to/your/music:/media/music:ro \
  jellyfin/jellyfin:latest
```

Complete the setup wizard at `http://<server>:8096` and add the music folder as
a library of type **Music**.

## Get the two values Voyager needs

Voyager authenticates with an API key rather than a username and password. A
key can be revoked from the server without changing the account password, which
is the right property for a credential living in a car.

**API key** — Dashboard → Advanced → API Keys → **+**. Name it "Voyager".

**User ID** — Dashboard → Users → click the user. The id is the `userId` in the
browser's address bar, a 32-character hex string.

## Point Voyager at it

Settings → **Jellyfin**:

| Field | Value |
| --- | --- |
| Server address | `http://192.168.1.100:8096` |
| API key | the key you just created |
| User ID | the hex id from the URL |

**Test connection** hits `/System/Info` with the key, so it verifies both the
address and the key in one go.

## Why the native API rather than the Subsonic bridge

Jellyfin ships a Subsonic compatibility layer, which would let Voyager reuse
the Navidrome path. It is only partially implemented and only present when the
admin enabled the plugin, so Voyager uses the native REST API instead — the
path that works on a stock install.

The token also travels in a header (`X-Emby-Token`) rather than a query string,
so unlike Subsonic it never appears in a URL a proxy might log.

## Direct play

Voyager requests `static=true`, which serves the original file rather than a
transcode. Transcoding adds latency at every track change and loads a server
that is often a low-power box, and formats a phone cannot decode natively are
rare.

If a specific file will not play, it is almost certainly an unusual codec —
transcode it once on the server rather than making Voyager transcode every
track forever.

## Navidrome or Jellyfin?

Both work. Navidrome is smaller, starts faster and is built only for music.
Jellyfin is worth it when you already run one. If both are configured, Voyager
uses Navidrome — the choice is resolved once at startup rather than being
changed mid-drive.
