# touchless-releases

Touchless — public release channel (signed APKs). Source is private.

## Download

- **Android app:** [latest Touchless APK](https://github.com/il90il90/touchless-releases/releases/latest) (`touchless-<version>.apk` + `.sha256`).

## Self-host the relay with Docker (optional)

Run the Touchless relay on your own computer instead of the Touchless cloud: your phone talks to your PC over
your home Wi-Fi, and a local AI in **LM Studio** can control the phone with no cloud account.

1. Install [Docker Desktop](https://www.docker.com/products/docker-desktop/) and start it.
2. Download **[touchless-docker.zip](https://github.com/il90il90/touchless-releases/releases/latest/download/touchless-docker.zip)** and unzip it.
3. Windows: double-click **`start.cmd`** · macOS/Linux: `./start.sh` — and follow the printed steps.

Full step-by-step guide: **[docker/README.md](docker/README.md)**

The [`docker/`](docker/) folder holds the same files as the zip. The relay image
(`touchless-relay-image.tar.gz` + `.sha256`) is attached to every release; the wizard downloads and verifies it for you.
