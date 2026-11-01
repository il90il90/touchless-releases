# Touchless self-hosted relay - one-click Windows wizard (PowerShell 5.1+).
# Double-click start.cmd, or run:  powershell -ExecutionPolicy Bypass -File start.ps1 [-Mode lan|local|public] [-LmStudioNoToken] [-Update]
#
#  1. checks Docker Desktop
#  2. downloads + verifies the relay image from the Touchless releases page (first run, or -Update)
#  3. writes .env (your Wi-Fi IP for LAN mode)
#  4. starts the relay with docker compose and prints what to type on the phone and in LM Studio
param(
    [ValidateSet("", "lan", "local", "public")][string]$Mode = "",
    [switch]$LmStudioNoToken,
    [switch]$Update
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$envFile = Join-Path $here ".env"
$imageTag = "touchless-relay:latest"
$releaseBase = "https://github.com/il90il90/touchless-releases/releases/latest/download"
$imageFile = "touchless-relay-image.tar.gz"

function Set-EnvValue([string]$Key, [string]$Value) {
    $found = $false
    $lines = @(
        foreach ($line in (Get-Content -LiteralPath $envFile)) {
            if ($line.StartsWith("$Key=")) {
                if (-not $found) { "$Key=$Value"; $found = $true }
            } else { $line }
        }
    )
    if (-not $found) { $lines += "$Key=$Value" }
    [System.IO.File]::WriteAllText($envFile,
        ($lines -join [Environment]::NewLine) + [Environment]::NewLine,
        (New-Object System.Text.UTF8Encoding($false)))
}

function Get-EnvValue([string]$Key, [string]$Default) {
    $line = Get-Content -LiteralPath $envFile | Where-Object { $_ -match "^$Key=" } | Select-Object -Last 1
    if ($line) { $v = ($line -split "=", 2)[1].Trim(); if ($v) { return $v } }
    return $Default
}

# Windows PowerShell 5.1 turns any stderr line of a native program into an error record, and with
# ErrorActionPreference=Stop that aborts the script (docker compose prints progress on stderr).
# Run docker with Continue and judge it only by its exit code. -Quiet hides all output.
function Invoke-Docker {
    param([Parameter(Position = 0)][string[]]$DockerArgs, [switch]$Quiet)
    $old = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        if ($Quiet) { & docker @DockerArgs *> $null }
        else { & docker @DockerArgs 2>&1 | ForEach-Object { Write-Host "$_" } }
        return $LASTEXITCODE
    } finally { $ErrorActionPreference = $old }
}

function Test-PrivateLanIp([string]$Ip) {
    if ($Ip -notmatch '^\d{1,3}(\.\d{1,3}){3}$') { return $false }
    $p = @($Ip.Split('.') | ForEach-Object { [int]$_ })
    if (@($p | Where-Object { $_ -lt 0 -or $_ -gt 255 }).Count -ne 0) { return $false }
    return ($p[0] -eq 10 -or ($p[0] -eq 172 -and $p[1] -ge 16 -and $p[1] -le 31) -or
            ($p[0] -eq 192 -and $p[1] -eq 168))
}

function Install-RelayImage {
    $tmp = Join-Path $env:TEMP ("touchless-" + [guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Path $tmp | Out-Null
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
        $local = Join-Path $here $imageFile
        $localSum = Join-Path $here "$imageFile.sha256"
        $archive = Join-Path $tmp $imageFile
        $sumFile = Join-Path $tmp "$imageFile.sha256"
        $offline = (-not $Update) -and (Test-Path -LiteralPath $local) -and (Test-Path -LiteralPath $localSum)
        if ($offline) {
            # Both files downloaded by hand next to this script (e.g. behind a proxy): verify locally, no network.
            Copy-Item -LiteralPath $localSum $sumFile
        } else {
            Write-Host "Downloading the relay image checksum..."
            Invoke-WebRequest -UseBasicParsing -Uri "$releaseBase/$imageFile.sha256" -OutFile $sumFile
        }
        $expected = ((Get-Content -LiteralPath $sumFile -Raw).Trim() -split '\s+')[0].ToLowerInvariant()
        if ($expected -notmatch '^[0-9a-f]{64}$') { throw "The image checksum file is not valid." }
        if ((Test-Path -LiteralPath $local) -and -not $Update -and
            (Get-FileHash -Algorithm SHA256 -LiteralPath $local).Hash.ToLowerInvariant() -eq $expected) {
            Write-Host "Using $imageFile next to this script (checksum OK)."
            $archive = $local
        } elseif ($offline) {
            throw "$imageFile next to this script does not match its .sha256. Download both again from the releases page."
        } else {
            Write-Host "Downloading the relay image (about 80 MB)..."
            Invoke-WebRequest -UseBasicParsing -Uri "$releaseBase/$imageFile" -OutFile $archive
            $actual = (Get-FileHash -Algorithm SHA256 -LiteralPath $archive).Hash.ToLowerInvariant()
            if ($actual -ne $expected) { throw "Downloaded image checksum does not match. Nothing was installed; try again." }
            Write-Host "Checksum OK." -ForegroundColor Green
        }
        if ((Invoke-Docker @("load", "-i", $archive)) -ne 0) { throw "docker load failed." }
    } finally {
        Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
    }
}

try {
    Write-Host "=== Touchless self-hosted relay (Docker) ===" -ForegroundColor Cyan
    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        throw "Docker is not installed. Install Docker Desktop: https://www.docker.com/products/docker-desktop/ , start it, then run start.cmd again."
    }
    if ((Invoke-Docker -Quiet @("info", "--format", "{{.ServerVersion}}")) -ne 0) {
        throw "Docker Desktop is not running. Start it, wait until it says 'Engine running', then run start.cmd again."
    }
    if ((Invoke-Docker -Quiet @("compose", "version")) -ne 0) { throw "Docker Compose v2 is required (included in Docker Desktop)." }

    if (-not (Test-Path -LiteralPath $envFile)) {
        Copy-Item (Join-Path $here ".env.example") $envFile
        Write-Host "Created .env"
    } else { Write-Host "Using your existing .env" }

    if ($Update -or (Invoke-Docker -Quiet @("image", "inspect", $imageTag)) -ne 0) { Install-RelayImage } else { Write-Host "Relay image already installed (run start.cmd update to get the newest)." }

    if (-not $Mode) {
        Write-Host ""
        Write-Host "How will your phone reach this computer?"
        Write-Host "  1) Same Wi-Fi / home network  (recommended, works with LM Studio)"
        Write-Host "  2) Only this computer (test; the phone cannot connect)"
        Write-Host "  3) Public HTTPS with my own domain (for ChatGPT / Claude on the web)"
        $choice = Read-Host "Choose 1, 2 or 3 [1]"
        $Mode = if ($choice -eq "2") { "local" } elseif ($choice -eq "3") { "public" } else { "lan" }
    }

    $compose = @("compose", "-f", "docker-compose.yml")
    $lanIp = ""
    $publicUrl = ""
    if ($Mode -eq "lan") {
        $candidates = @(Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
            Where-Object {
                (Test-PrivateLanIp $_.IPAddress) -and
                $_.InterfaceAlias -notmatch '(?i)(vEthernet|WSL|Docker|Loopback|Virtual|Tailscale|WireGuard|VPN)'
            } | Sort-Object InterfaceMetric | Select-Object -ExpandProperty IPAddress -Unique)
        if ($candidates.Count -eq 1) {
            $lanIp = $candidates[0]
            Write-Host "This computer's Wi-Fi/LAN IP: $lanIp"
        } else {
            Write-Host ("Private IPs on this computer: " + ($candidates -join ", "))
            $lanIp = (Read-Host "Type the IP of the network your phone is on").Trim()
        }
        if (-not (Test-PrivateLanIp $lanIp)) { throw "That is not a private network IPv4 (192.168.x.x / 10.x.x.x / 172.16-31.x.x)." }
        if ($candidates.Count -gt 0 -and $lanIp -notin $candidates) { throw "That IP is not on this computer." }
        Set-EnvValue "RELAY_LAN_IP" $lanIp
        Set-EnvValue "RELAY_PUBLIC_URL" ""
        $compose += @("-f", "docker-compose.lan.yml")
    } elseif ($Mode -eq "public") {
        $domain = (Read-Host "Your public domain for the relay (e.g. relay.mydomain.com)").Trim().ToLowerInvariant()
        if ($domain -notmatch '^([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,63}$' -or
            $domain -eq "relay.example.com" -or $domain.Length -gt 253) {
            throw "A real public domain is required for public HTTPS."
        }
        $email = (Read-Host "Email for the free TLS certificate").Trim()
        if ($email -notmatch '^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$') { throw "Invalid email." }
        $publicUrl = "https://$domain"
        Set-EnvValue "RELAY_LAN_IP" ""
        Set-EnvValue "RELAY_DOMAIN" $domain
        Set-EnvValue "ACME_EMAIL" $email
        Set-EnvValue "RELAY_PUBLIC_URL" $publicUrl
        $compose += @("-f", "docker-compose.tls.yml")
        Write-Host "Public mode: the domain's DNS must point here and TCP 80/443 must reach this computer." -ForegroundColor Yellow
    } else {
        Set-EnvValue "RELAY_LAN_IP" ""
        Set-EnvValue "RELAY_PUBLIC_URL" ""
    }

    $noToken = $false
    if ($Mode -ne "public") {
        if (-not $LmStudioNoToken) {
            Write-Host ""
            Write-Host "LM Studio on THIS computer can use Touchless without a token (localhost only)."
            Write-Host "Any program on this computer could then control the phone. Only on a personal, trusted PC."
            $ans = Read-Host "Enable LM Studio without token? [y/N]"
            $LmStudioNoToken = ($ans -match '^(y|yes)$')
        }
        if ($LmStudioNoToken) { $noToken = $true; $compose += @("-f", "docker-compose.local-mcp.yml") }
    }

    Push-Location $here
    try {
        if ((Invoke-Docker ($compose + @("up", "-d", "--remove-orphans"))) -ne 0) { throw "docker compose up failed (see the message above)." }

        $hostPort = [int](Get-EnvValue "RELAY_PORT" "8787")
        $healthy = $false
        for ($i = 0; $i -lt 15; $i++) {
            $r = & curl.exe -s --noproxy "*" --max-time 3 "http://127.0.0.1:$hostPort/healthz" 2>$null
            if ("$r".Trim() -eq "ok") { $healthy = $true; break }
            Start-Sleep -Seconds 2
        }
        Write-Host ""
        if ($healthy) { Write-Host "Relay is running: http://127.0.0.1:$hostPort/healthz -> ok" -ForegroundColor Green }
        else { Write-Host "Relay did not answer yet. Check: docker compose logs relay" -ForegroundColor Yellow }

        Write-Host ""
        Write-Host "==================== WHAT TO DO NOW ====================" -ForegroundColor Cyan
        Write-Host "1) Phone: install Touchless  https://github.com/il90il90/touchless-releases/releases/latest"
        if ($Mode -eq "lan") {
            $baseUrl = "http://${lanIp}:$hostPort"
            Write-Host "2) On the phone's browser open  $baseUrl/healthz  -> must show: ok"
            Write-Host "   (if it does not load, see 'Phone cannot connect' in README.md: Windows firewall)"
            Write-Host "3) Touchless -> Settings -> Advanced -> Relay server -> Custom / self-hosted"
            Write-Host "     Relay address:  $baseUrl"
            Write-Host "     Turn ON 'Allow LAN-only cleartext (http/ws)'  ->  Save & connect"
            Write-Host "4) LM Studio on this computer -> Program -> Install -> Edit mcp.json:"
            if ($noToken) {
                Write-Host '     { "mcpServers": { "touchless": { "url": "http://127.0.0.1:8788/mcp" } } }'
            } else {
                Write-Host '     { "mcpServers": { "touchless": { "url": "<Copy address from Touchless>",'
                Write-Host '       "headers": { "Authorization": "Bearer tlk.<your API key>" } } } }'
                Write-Host "     Address: Touchless -> Settings -> AI connection -> Copy address (starts with $baseUrl/mcp/)"
                Write-Host "     API key: same screen -> Advanced -> API key (shown once, never share it)."
            }
            Write-Host "Cloud ChatGPT/Claude cannot reach a home IP; for them use mode 3 or a VPN." -ForegroundColor Yellow
        } elseif ($Mode -eq "public") {
            Write-Host "2) Touchless -> Settings -> Advanced -> Relay server -> Custom / self-hosted:  $publicUrl"
            Write-Host "3) Your AI's MCP connector:  $publicUrl/mcp  (copy the address from Touchless -> Settings -> AI connection)"
        } else {
            Write-Host "2) Localhost test only. For the phone run:  start.cmd lan"
            if ($noToken) { Write-Host "   LM Studio: http://127.0.0.1:8788/mcp (no token) once a phone is connected." }
        }
        Write-Host "Stop: stop.cmd    Update: start.cmd update    Logs: docker compose logs -f relay"
        Write-Host "=========================================================" -ForegroundColor Cyan
    } finally { Pop-Location }
} catch {
    Write-Host ""
    Write-Host "Setup failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
