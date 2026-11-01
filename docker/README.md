# Touchless — run your own relay with Docker (self-hosted)

**עברית: [README.he.md](README.he.md)**

Touchless normally connects your phone and your AI through the Touchless cloud relay. With this
folder you run that relay **on your own computer** instead, so phone commands never leave your home
network, and you can use a **local AI in LM Studio** with no cloud account at all.

```
LM Studio / AI app ──/mcp──►  Touchless relay (Docker, your PC)  ◄──Wi-Fi── Touchless app (phone)
```

You need about 10 minutes. No source code, no build, no programming.

---

## What you need

| | |
|---|---|
| A computer that stays on | Windows 10/11, macOS, or Linux (amd64). Apple Silicon Macs work through Docker's emulation. |
| **Docker Desktop** (Windows/macOS) or Docker Engine + Compose (Linux) | [docker.com/products/docker-desktop](https://www.docker.com/products/docker-desktop/) — install, open it, wait for **Engine running**. |
| An Android phone with **Touchless** | [Download the latest APK](https://github.com/il90il90/touchless-releases/releases/latest) |
| Phone and computer on the **same Wi-Fi** | A home network. Guest Wi-Fi often blocks devices from seeing each other. |
| (Optional) **LM Studio** | [lmstudio.ai](https://lmstudio.ai/) with a model that supports **tool use**. |

---

## Step 1 — Download this folder

Download **[touchless-docker.zip](https://github.com/il90il90/touchless-releases/releases/latest/download/touchless-docker.zip)**
and unzip it anywhere (for example `Documents\touchless-docker`).

The relay image itself (`touchless-relay-image.tar.gz`, ~80 MB) is downloaded and checksum-verified
by the wizard in the next step. You do not need to download it by hand.

## Step 2 — Start the relay (one click)

- **Windows:** double-click **`start.cmd`**.
- **macOS / Linux:** open a terminal in the folder and run `chmod +x start.sh stop.sh && ./start.sh`.

The wizard asks two questions:

1. **How will your phone reach this computer?** Press **Enter** for **1 — Same Wi-Fi** (recommended).
   It finds your computer's Wi-Fi IP (for example `192.168.1.50`) by itself.
2. **Enable LM Studio without token?** Answer **y** only if LM Studio runs on **this** computer and
   it is your personal, trusted computer (see [Security](#security)). Otherwise press Enter.

At the end it prints a box called **WHAT TO DO NOW** with the exact addresses for your network.
Keep that window open while you do steps 3–5.

> Windows may ask whether Docker may use the network. Allow it for **Private networks** only.

## Step 3 — Check the phone can reach the computer

On the **phone**, open the browser and go to the address from the box, ending in `/healthz`:

```
http://192.168.1.50:8787/healthz
```

It must show **`ok`**. If it does not load, see [Phone cannot connect](#phone-cannot-connect) before going on.

## Step 4 — Point Touchless at your relay

On the phone:

1. Open **Touchless → Settings → Advanced → Relay server**.
2. Tap **Custom / self-hosted**.
3. **Relay address:** `http://192.168.1.50:8787` (your IP from the box, **no** `/mcp` at the end).
4. Turn **on** **Allow LAN-only cleartext (http/ws)**. This is needed for a home-network `http://` address.
5. Tap **Save & connect**.

Touchless reconnects to your computer. **AI agent** must stay **On** on the Touchless home screen.

> This screen is protected: an AI cannot change it for you. You do this step by hand, once.

## Step 5 — Connect LM Studio (optional)

1. In LM Studio, download and load a model that supports tool calling (for example a Qwen 3 / Qwen 3.5
   "instruct" model). In the model's load settings raise **Context Length** to at least **16384**
   (Touchless has many tools).
2. Open **Program → Install → Edit mcp.json** and add a `touchless` entry. Keep any other servers you already have.

**If you answered "y" to "LM Studio without token":**

```json
{
  "mcpServers": {
    "touchless": { "url": "http://127.0.0.1:8788/mcp" }
  }
}
```

**Otherwise (API key, works from any computer on your Wi-Fi):**

1. On the phone (after step 4): **Touchless → Settings → AI connection → Copy address**. It now looks like
   `http://192.168.1.50:8787/mcp/abc123…` (your relay + your phone's id).
2. Same screen → **Advanced → API key**: type a name (e.g. *LM Studio*), create it, copy the key (`tlk.…`).
   It is shown **once**; treat it like a password.
3. In `mcp.json`:

```json
{
  "mcpServers": {
    "touchless": {
      "url": "http://192.168.1.50:8787/mcp/PASTE-YOUR-DEVICE-ID",
      "headers": { "Authorization": "Bearer tlk.PASTE-YOUR-API-KEY" }
    }
  }
}
```

Never post the key or put it in the URL. You can revoke it any time on the same screen.

3. Save, make sure the **touchless** integration is switched on in the chat, and ask:
   *"Call the Touchless get_device_info tool and tell me only what it returns."*
   You should see your phone's model and battery level.

If LM Studio says the request is bigger than the context: raise **Context Length**, or turn off tools you
do not need in the integration's tool list.

---

## Everyday use

| Want to… | Windows | macOS / Linux |
|---|---|---|
| Start again (after a reboot it starts by itself) | `start.cmd` | `./start.sh` |
| Stop | `stop.cmd` | `./stop.sh` |
| Update to the newest relay | `start.cmd update` | `./start.sh update` |
| See the log | `docker compose logs -f relay` | same |
| Go back to the Touchless cloud | Touchless → Settings → Advanced → Relay server → **Touchless cloud (Default)** | same |

Your settings live in `.env` and the relay's small state in the Docker volume `relay-data`. Stopping and
updating keep both. `docker compose down -v` **deletes** the volume; you rarely want that.

### Manual commands (instead of the wizard)

```bash
cp .env.example .env                 # then set RELAY_LAN_IP=<your Wi-Fi IP> in .env
docker load -i touchless-relay-image.tar.gz
docker compose -f docker-compose.yml -f docker-compose.lan.yml up -d
# add  -f docker-compose.local-mcp.yml  for LM Studio without token
```

## What is in this folder

| File | What it does |
|---|---|
| `start.cmd` / `start.ps1` | Windows wizard: download + verify image, write `.env`, start, print the addresses. |
| `start.sh` | The same wizard for macOS / Linux. |
| `stop.cmd` / `stop.sh` | Stop the relay (data is kept). |
| `docker-compose.yml` | The relay itself, reachable only from this computer (`127.0.0.1:8787`). |
| `docker-compose.lan.yml` | Adds your Wi-Fi IP so the phone can connect. |
| `docker-compose.local-mcp.yml` | Optional: LM Studio on this computer without a token (`127.0.0.1:8788`). |
| `docker-compose.tls.yml` + `Caddyfile` | Optional: public HTTPS with your own domain (for ChatGPT / Claude on the web). |
| `.env.example` | All settings, explained. The wizard copies it to `.env`. |

## Cloud AIs (ChatGPT, Claude on the web)

A cloud AI runs on the internet and **cannot** reach `192.168.x.x`. Options:

- Keep using the default **Touchless cloud** relay (simplest), or
- Run `start.cmd public` / `./start.sh public` with **your own domain** whose DNS points at this computer
  and with ports 80/443 open to it. Caddy gets a free HTTPS certificate automatically. In Touchless use
  `https://your-domain` (cleartext switch **off**), and give the AI the MCP address shown in
  **Touchless → Settings → AI connection**.
- For your own devices only, a VPN (Tailscale / WireGuard) avoids opening any port.

## Phone cannot connect

Work through these in order:

1. **Same network?** The phone must be on the same Wi-Fi as the computer, not mobile data and not a guest Wi-Fi.
2. **Right IP?** Run `ipconfig` (Windows) and use the **Wi-Fi** adapter's IPv4. Not `127.0.0.1`, not `172.x`
   (that is Docker/WSL). If your IP changed (new router lease), run `start.cmd lan` again and update the phone.
3. **Windows network = Private?** In PowerShell: `Get-NetConnectionProfile`. If your home Wi-Fi says
   *Public*, open PowerShell **as Administrator**:
   `Set-NetConnectionProfile -InterfaceIndex <number> -NetworkCategory Private`
4. **Windows firewall:** in PowerShell **as Administrator**:
   ```powershell
   New-NetFirewallRule -DisplayName "Touchless relay 8787" -Direction Inbound -Protocol TCP -LocalPort 8787 -RemoteAddress LocalSubnet -Profile Private -Action Allow
   ```
   macOS: System Settings → Network → Firewall → allow Docker. Linux (ufw): `sudo ufw allow from 192.168.0.0/16 to any port 8787 proto tcp`.
5. **Port shown?** `docker ps` must list `<your-IP>:8787->8787/tcp`. If you see only `127.0.0.1:8787`, you started
   without LAN mode: run `start.cmd lan`.
6. **Touchless says the address is unencrypted:** turn on **Allow LAN-only cleartext (http/ws)**.

| Message | Meaning |
|---|---|
| `No phone connected. Connect Touchless first.` (LM Studio) | The relay runs, but the phone is not on it yet: finish step 4 and keep **AI agent** On. |
| `401` | Wrong, revoked or missing API key in LM Studio's `Authorization` header, or the address is not the one from **Copy address**. |
| `403` | Touchless's **IP access** list blocks that computer: Settings → Safety & approvals. |
| Container name `touchless-relay` already in use | Another copy of the relay runs: stop it first (`docker stop touchless-relay`). |
| Port already in use | Change `RELAY_PORT` in `.env`, then start again. |
| Image download fails behind a company proxy | Download `touchless-relay-image.tar.gz` + `.sha256` from the releases page into this folder and run the wizard again. |

## Security

- The relay listens on **this computer** and, in LAN mode, on **your Wi-Fi IP only**, never on all interfaces.
  **Never port-forward 8787 or 8788 on your router.**
- Home-network `http://` is not encrypted. Use it only on your own trusted Wi-Fi; for anything else use HTTPS.
- AI clients sign in with a phone-approved sign-in or an API key you create in Touchless and can revoke.
  The relay stores only hashes and never prints tokens or keys.
- **LM Studio without token** (`127.0.0.1:8788`) lets **any program on this computer** control the paired phone.
  Enable it only on a personal computer you trust, and never expose that port.
- Touchless's own safety settings (approval mode, protected screens, IP access, active hours) apply the same way
  on your relay as on the cloud.
