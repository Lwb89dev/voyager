# Navidrome

Navidrome is a self-hosted music server (GPL v3) that speaks the Subsonic API.
It is the recommended backend for Voyager: it is small, runs on ARM, and does
one thing.

## Run the server

```bash
docker run -d \
  --name navidrome \
  --restart unless-stopped \
  -p 4533:4533 \
  -v /path/to/your/music:/music:ro \
  -v navidrome_data:/data \
  -e ND_SCANSCHEDULE=1h \
  -e ND_LOGLEVEL=info \
  navidrome/navidrome:latest
```

Mounting the music read-only (`:ro`) is worth doing: Navidrome never needs to
write to your library, and a container that cannot write cannot corrupt it.

Open `http://<server>:4533` and create the admin account on first launch. Wait
for the initial scan to finish before pointing Voyager at it — an empty library
looks identical to a connection failure from the car.

## Point Voyager at it

Settings → **Navidrome**:

| Field | Value |
| --- | --- |
| Server address | `http://192.168.1.100:4533` — no trailing slash |
| Username | your Navidrome user |
| Password | that user's password |

Press **Test connection** before saving. It runs a real `ping` against the
server, so a failure here tells you which of the three fields is wrong while
you are still parked.

Create a separate, non-admin Navidrome user for the car. A device mounted on a
windscreen is a device that gets stolen, and the credential it holds should not
be your admin one.

## How Voyager authenticates

Not with the password in the URL. Voyager uses Subsonic's salted-token scheme:
a fresh random salt per request, with `t = md5(password + salt)` alongside it.
The password never crosses the wire and a captured URL cannot be replayed.

MD5 is a poor hash in 2026, but it is what the protocol mandates; what the
scheme actually buys is that the plaintext password stays on the device. Any
Navidrome from the last several years supports it.

The password is stored in the AES-encrypted Hive settings box, with the key in
the Android Keystore.

## Plain HTTP on your LAN

Voyager's manifest allows cleartext traffic, because a Navidrome on a home
network almost never has a TLS certificate and refusing plain HTTP would mean
refusing the main use case.

If the server is reachable from outside your network, put it behind a reverse
proxy with TLS and use the `https://` address instead. Over the open internet,
salted-token auth protects the password but nothing else — the stream URLs and
your listening are in the clear.

## What Voyager asks for

Only what a car UI can use: starred albums, recent albums, an album's tracks,
and a random-song queue for the shuffle button. There is no full library
browser, deliberately — scrolling forty thousand tracks at a traffic light is
not a thing anyone should do.

## Troubleshooting

| Symptom | Cause |
| --- | --- |
| "Wrong username or password" | Credentials, or a Navidrome older than API 1.13 |
| Connection refused | Wrong port, or the container is not running |
| Connects but no albums | Scan not finished, or the library mount is empty |
| Plays then stops after a few tracks | Server transcoding and running out of CPU — set the player quality to "original" in Navidrome |
