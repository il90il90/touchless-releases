#!/usr/bin/env bash
# Touchless self-hosted relay - one-click wizard for Linux / macOS / WSL.
#   ./start.sh            asks a few questions
#   ./start.sh lan        phone on the same Wi-Fi
#   ./start.sh local      this computer only
#   ./start.sh public     your own HTTPS domain
#   ./start.sh update     download the newest relay image, then start
# Env: LMSTUDIO_NO_TOKEN=1 enables the localhost no-token MCP without asking.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
cd "$here"
env_file="$here/.env"
image_tag="touchless-relay:latest"
release_base="https://github.com/il90il90/touchless-releases/releases/latest/download"
image_file="touchless-relay-image.tar.gz"

mode=""; update=0
for a in "$@"; do
  case "$a" in
    lan|local|public) mode="$a" ;;
    update) update=1 ;;
    *) echo "Unknown option: $a (use lan, local, public, update)"; exit 2 ;;
  esac
done

die() { echo; echo "Setup failed: $*" >&2; exit 1; }

set_env() { # KEY VALUE - replace or append, keep the rest of .env
  local key="$1" val="$2" tmp
  tmp="$(mktemp)"
  awk -v k="$key" -v v="$val" 'BEGIN{d=0} index($0, k"=")==1 {if(!d){print k"="v; d=1}; next} {print} END{if(!d) print k"="v}' \
    "$env_file" > "$tmp" && cat "$tmp" > "$env_file" && rm -f "$tmp"
}
get_env() { local v; v="$(sed -n "s/^$1=//p" "$env_file" | tail -n 1 | tr -d '[:space:]')"; echo "${v:-$2}"; }

is_private_ip() {
  [[ "$1" =~ ^([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})$ ]] || return 1
  local a=${BASH_REMATCH[1]} b=${BASH_REMATCH[2]} c=${BASH_REMATCH[3]} d=${BASH_REMATCH[4]}
  for o in "$a" "$b" "$c" "$d"; do (( o <= 255 )) || return 1; done
  (( a == 10 )) || (( a == 172 && b >= 16 && b <= 31 )) || (( a == 192 && b == 168 ))
}

sha256_of() { if command -v sha256sum >/dev/null; then sha256sum "$1" | cut -d' ' -f1; else shasum -a 256 "$1" | cut -d' ' -f1; fi; }

install_image() {
  local tmp archive expected actual
  tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' RETURN
  local offline=0
  if [[ $update -eq 0 && -f "$here/$image_file" && -f "$here/$image_file.sha256" ]]; then
    # Both files downloaded by hand next to this script (e.g. behind a proxy): verify locally, no network.
    offline=1; cp "$here/$image_file.sha256" "$tmp/sum"
  else
    echo "Downloading the relay image checksum..."
    curl -fsSL "$release_base/$image_file.sha256" -o "$tmp/sum" || die "Could not download from the releases page."
  fi
  expected="$(awk '{print tolower($1)}' "$tmp/sum")"
  [[ "$expected" =~ ^[0-9a-f]{64}$ ]] || die "The image checksum file is not valid."
  if [[ -f "$here/$image_file" && $update -eq 0 && "$(sha256_of "$here/$image_file")" == "$expected" ]]; then
    echo "Using $image_file next to this script (checksum OK)."
    archive="$here/$image_file"
  elif [[ $offline -eq 1 ]]; then
    die "$image_file next to this script does not match its .sha256. Download both again from the releases page."
  else
    echo "Downloading the relay image (about 80 MB)..."
    archive="$tmp/$image_file"
    curl -fSL --progress-bar "$release_base/$image_file" -o "$archive" || die "Image download failed."
    actual="$(sha256_of "$archive")"
    [[ "$actual" == "$expected" ]] || die "Downloaded image checksum does not match. Nothing was installed; try again."
    echo "Checksum OK."
  fi
  docker load -i "$archive" || die "docker load failed."
}

echo "=== Touchless self-hosted relay (Docker) ==="
command -v docker >/dev/null || die "Docker is not installed: https://docs.docker.com/get-docker/"
docker info >/dev/null 2>&1 || die "Docker is not running (or this user cannot use it: try sudo, or add yourself to the docker group)."
docker compose version >/dev/null 2>&1 || die "Docker Compose v2 is required (the 'docker compose' plugin)."
command -v curl >/dev/null || die "curl is required."

if [[ ! -f "$env_file" ]]; then cp "$here/.env.example" "$env_file"; echo "Created .env"; else echo "Using your existing .env"; fi

if [[ $update -eq 1 ]] || ! docker image inspect "$image_tag" >/dev/null 2>&1; then
  install_image
else
  echo "Relay image already installed (./start.sh update gets the newest)."
fi

if [[ -z "$mode" ]]; then
  echo
  echo "How will your phone reach this computer?"
  echo "  1) Same Wi-Fi / home network  (recommended, works with LM Studio)"
  echo "  2) Only this computer (test; the phone cannot connect)"
  echo "  3) Public HTTPS with my own domain (for ChatGPT / Claude on the web)"
  read -r -p "Choose 1, 2 or 3 [1]: " choice
  case "${choice:-1}" in 2) mode=local ;; 3) mode=public ;; *) mode=lan ;; esac
fi

compose=(docker compose -f docker-compose.yml)
lan_ip=""; public_url=""
if [[ "$mode" == "lan" ]]; then
  candidates=()
  if command -v ip >/dev/null; then
    while read -r addr; do is_private_ip "$addr" && candidates+=("$addr"); done < <(
      ip -4 -o addr show scope global 2>/dev/null | grep -Ev ' (docker|br-|veth|virbr|tailscale|wg|tun|zt)' | awk '{print $4}' | cut -d/ -f1)
  else
    for ifc in en0 en1; do addr="$(ipconfig getifaddr "$ifc" 2>/dev/null || true)"; [[ -n "$addr" ]] && is_private_ip "$addr" && candidates+=("$addr"); done
  fi
  if [[ ${#candidates[@]} -eq 1 ]]; then
    lan_ip="${candidates[0]}"; echo "This computer's Wi-Fi/LAN IP: $lan_ip"
  else
    echo "Private IPs on this computer: ${candidates[*]:-none found}"
    read -r -p "Type the IP of the network your phone is on: " lan_ip
  fi
  is_private_ip "$lan_ip" || die "That is not a private network IPv4 (192.168.x.x / 10.x.x.x / 172.16-31.x.x)."
  set_env RELAY_LAN_IP "$lan_ip"; set_env RELAY_PUBLIC_URL ""
  compose+=(-f docker-compose.lan.yml)
elif [[ "$mode" == "public" ]]; then
  read -r -p "Your public domain for the relay (e.g. relay.mydomain.com): " domain
  domain="$(echo "$domain" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')"
  [[ "$domain" =~ ^([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,63}$ && "$domain" != "relay.example.com" ]] || die "A real public domain is required."
  read -r -p "Email for the free TLS certificate: " email
  [[ "$email" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]] || die "Invalid email."
  public_url="https://$domain"
  set_env RELAY_LAN_IP ""; set_env RELAY_DOMAIN "$domain"; set_env ACME_EMAIL "$email"; set_env RELAY_PUBLIC_URL "$public_url"
  compose+=(-f docker-compose.tls.yml)
  echo "Public mode: the domain's DNS must point here and TCP 80/443 must reach this computer."
else
  set_env RELAY_LAN_IP ""; set_env RELAY_PUBLIC_URL ""
fi

no_token=0
if [[ "$mode" != "public" ]]; then
  if [[ "${LMSTUDIO_NO_TOKEN:-}" == "1" ]]; then no_token=1
  else
    echo
    echo "LM Studio on THIS computer can use Touchless without a token (localhost only)."
    echo "Any program on this computer could then control the phone. Only on a personal, trusted computer."
    read -r -p "Enable LM Studio without token? [y/N]: " ans
    [[ "$ans" =~ ^([yY]|[yY][eE][sS])$ ]] && no_token=1
  fi
  [[ $no_token -eq 1 ]] && compose+=(-f docker-compose.local-mcp.yml)
fi

"${compose[@]}" up -d --remove-orphans || die "docker compose up failed (see the message above)."

port="$(get_env RELAY_PORT 8787)"
healthy=0
for _ in $(seq 1 15); do
  [[ "$(curl -s --noproxy '*' --max-time 3 "http://127.0.0.1:$port/healthz" || true)" == "ok" ]] && { healthy=1; break; }
  sleep 2
done
echo
if [[ $healthy -eq 1 ]]; then echo "Relay is running: http://127.0.0.1:$port/healthz -> ok"
else echo "Relay did not answer yet. Check: docker compose logs relay"; fi

echo
echo "==================== WHAT TO DO NOW ===================="
echo "1) Phone: install Touchless  https://github.com/il90il90/touchless-releases/releases/latest"
if [[ "$mode" == "lan" ]]; then
  base="http://$lan_ip:$port"
  echo "2) On the phone's browser open  $base/healthz  -> must show: ok"
  echo "   (if it does not load, see 'Phone cannot connect' in README.md: firewall)"
  echo "3) Touchless -> Settings -> Advanced -> Relay server -> Custom / self-hosted"
  echo "     Relay address:  $base"
  echo "     Turn ON 'Allow LAN-only cleartext (http/ws)'  ->  Save & connect"
  echo "4) LM Studio on this computer -> Program -> Install -> Edit mcp.json:"
  if [[ $no_token -eq 1 ]]; then
    echo '     { "mcpServers": { "touchless": { "url": "http://127.0.0.1:8788/mcp" } } }'
  else
    echo '     { "mcpServers": { "touchless": { "url": "<Copy address from Touchless>",'
    echo '       "headers": { "Authorization": "Bearer tlk.<your API key>" } } } }'
    echo "     Address: Touchless -> Settings -> AI connection -> Copy address (starts with $base/mcp/)"
    echo "     API key: same screen -> Advanced -> API key (shown once, never share it)."
  fi
  echo "Cloud ChatGPT/Claude cannot reach a home IP; for them use mode 3 or a VPN."
elif [[ "$mode" == "public" ]]; then
  echo "2) Touchless -> Settings -> Advanced -> Relay server -> Custom / self-hosted:  $public_url"
  echo "3) Your AI's MCP connector:  $public_url/mcp  (copy the address from Touchless -> Settings -> AI connection)"
else
  echo "2) Localhost test only. For the phone run:  ./start.sh lan"
  [[ $no_token -eq 1 ]] && echo "   LM Studio: http://127.0.0.1:8788/mcp (no token) once a phone is connected."
fi
admin_port="$(get_env ADMIN_PORT 8789)"
echo
echo "Setup page with buttons and settings (this computer): http://127.0.0.1:$admin_port/"
echo "Stop: ./stop.sh    Update: ./start.sh update    Logs: docker compose logs -f relay"
echo "========================================================="
if [[ $healthy -eq 1 && -z "${TOUCHLESS_NO_BROWSER:-}" ]]; then
  if command -v open >/dev/null 2>&1 && [[ "$(uname)" == "Darwin" ]]; then open "http://127.0.0.1:$admin_port/" >/dev/null 2>&1 || true
  elif command -v xdg-open >/dev/null 2>&1 && [[ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]]; then xdg-open "http://127.0.0.1:$admin_port/" >/dev/null 2>&1 || true
  fi
fi
