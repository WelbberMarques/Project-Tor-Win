# TorProxy-Win.ps1
# Tor + tun2socks (roteamento 100% do trafego) + Fake GPS
# Uso: .\TorProxy-Win.ps1 -Action [install|start|stop|status|fakegps|uninstall]
# Requer PowerShell como Administrador

param(
    [string]$Action      = "help",
    [string]$Bridge      = "",
    [string]$ExitCountry = ""
)

# ─── Banner ───────────────────────────────────────────────────────────────────
function Show-Banner {
    $w = 62
    $line = '═' * $w
    Write-Host ""
    Write-Host "  ╔$line╗" -ForegroundColor DarkCyan
    Write-Host "  ║$((' ' * $w))║" -ForegroundColor DarkCyan
    Write-Host "  ║" -NoNewline -ForegroundColor DarkCyan
    Write-Host "    ████████╗ ██████╗ ██████╗     ██╗    ██╗██╗███╗  ██╗      " -NoNewline -ForegroundColor Cyan
    Write-Host "║" -ForegroundColor DarkCyan
    Write-Host "  ║" -NoNewline -ForegroundColor DarkCyan
    Write-Host "       ██╔══╝██╔═══██╗██╔══██╗    ██║    ██║██║████╗ ██║      " -NoNewline -ForegroundColor Cyan
    Write-Host "║" -ForegroundColor DarkCyan
    Write-Host "  ║" -NoNewline -ForegroundColor DarkCyan
    Write-Host "       ██║   ██║   ██║██████╔╝    ██║ █╗ ██║██║██╔██╗██║      " -NoNewline -ForegroundColor Cyan
    Write-Host "║" -ForegroundColor DarkCyan
    Write-Host "  ║" -NoNewline -ForegroundColor DarkCyan
    Write-Host "       ██║   ██║   ██║██╔══██╗    ██║███╗██║██║██║╚████║      " -NoNewline -ForegroundColor Cyan
    Write-Host "║" -ForegroundColor DarkCyan
    Write-Host "  ║" -NoNewline -ForegroundColor DarkCyan
    Write-Host "       ██║   ╚██████╔╝██║  ██║    ╚███╔███╔╝██║██║ ╚███║      " -NoNewline -ForegroundColor Cyan
    Write-Host "║" -ForegroundColor DarkCyan
    Write-Host "  ║" -NoNewline -ForegroundColor DarkCyan
    Write-Host "       ╚═╝    ╚═════╝ ╚═╝  ╚═╝     ╚══╝╚══╝ ╚═╝╚═╝  ╚══╝      " -NoNewline -ForegroundColor DarkCyan
    Write-Host "║" -ForegroundColor DarkCyan
    Write-Host "  ║$((' ' * $w))║" -ForegroundColor DarkCyan
    Write-Host "  ╠$line╣" -ForegroundColor DarkCyan

    # linha 1 — descricao
    $l1 = "  Tor + tun2socks   *   Windows   *   PowerShell"
    Write-Host "  ║" -NoNewline -ForegroundColor DarkCyan
    Write-Host ($l1 + (' ' * ($w - $l1.Length))) -NoNewline -ForegroundColor White
    Write-Host "║" -ForegroundColor DarkCyan

    # linha 2 — autor / versao
    $p1 = "  Autor : "; $n1 = "Welbber Marques"; $p2 = "     Versao : "; $n2 = "2.0"
    $pad2 = $w - $p1.Length - $n1.Length - $p2.Length - $n2.Length
    Write-Host "  ║" -NoNewline -ForegroundColor DarkCyan
    Write-Host $p1 -NoNewline -ForegroundColor Gray
    Write-Host $n1 -NoNewline -ForegroundColor Yellow
    Write-Host $p2 -NoNewline -ForegroundColor Gray
    Write-Host $n2 -NoNewline -ForegroundColor Yellow
    Write-Host (' ' * $pad2) -NoNewline
    Write-Host "║" -ForegroundColor DarkCyan

    # linha 3 — github
    $gp = "  GitHub: "; $gu = "github.com/WelbberMarques/TorProxy-Win"
    $pad3 = $w - $gp.Length - $gu.Length
    Write-Host "  ║" -NoNewline -ForegroundColor DarkCyan
    Write-Host $gp -NoNewline -ForegroundColor Gray
    Write-Host $gu -NoNewline -ForegroundColor Blue
    Write-Host (' ' * $pad3) -NoNewline
    Write-Host "║" -ForegroundColor DarkCyan

    Write-Host "  ╚$line╝" -ForegroundColor DarkCyan
    Write-Host ""
}

# ─── Configuracoes ────────────────────────────────────────────────────────────
$TorDir         = "$env:ProgramData\TorProxy"
$TorExe         = "$TorDir\tor\tor.exe"
$TorrcPath      = "$TorDir\torrc"
$TunExe         = "$TorDir\tun2socks.exe"
$WintunDll      = "$TorDir\wintun.dll"
$TorBrowserExe  = "$TorDir\tor-browser\Browser\firefox.exe"
$LogTor      = "$TorDir\tor.log"
$RouteFile   = "$TorDir\tor-relay-routes.txt"
$PTExe       = "$TorDir\tor\pluggable_transports\lyrebird.exe"
$SocksPort   = 9050
$DNSPort     = 9053
$TunName     = "TorTun0"
$TunIP       = "198.18.0.1"
$TunMask     = "255.255.0.0"
$TunGW       = "198.18.0.2"

# ─── Helpers ─────────────────────────────────────────────────────────────────
function Write-OK($m)   { Write-Host "[+] $m" -ForegroundColor Green  }
function Write-Info($m) { Write-Host "[*] $m" -ForegroundColor Cyan   }
function Write-Warn($m) { Write-Host "[!] $m" -ForegroundColor Yellow }
function Write-Err($m)  { Write-Host "[-] $m" -ForegroundColor Red    }

function Test-Admin {
    $p = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-RealGateway {
    $route = Get-NetRoute -DestinationPrefix "0.0.0.0/0" -ErrorAction SilentlyContinue |
             Where-Object { $_.NextHop -ne "0.0.0.0" } |
             Sort-Object RouteMetric | Select-Object -First 1
    return $route
}

function Get-TorVersion {
    try {
        $page = Invoke-WebRequest "https://dist.torproject.org/torbrowser/" -UseBasicParsing -TimeoutSec 10
        $v = [regex]::Matches($page.Content, '(\d+\.\d+\.\d+)/') |
             ForEach-Object { $_.Groups[1].Value } |
             Sort-Object { [version]$_ } | Select-Object -Last 1
        return $v
    } catch { return "14.0.7" }
}

# ─── INSTALACAO ───────────────────────────────────────────────────────────────
function Install-All {
    if (!(Test-Admin)) { Write-Err "Execute como Administrador."; exit 1 }

    New-Item -ItemType Directory -Path $TorDir -Force | Out-Null

    # Busca versao antes de qualquer bloco condicional
    Write-Info "Buscando versao atual do Tor..."
    $ver = Get-TorVersion
    Write-Info "Versao: $ver"

    # ── Tor Expert Bundle ──────────────────────────────────────────────────────
    if (!(Test-Path $TorExe)) {
        $url = "https://dist.torproject.org/torbrowser/$ver/tor-expert-bundle-windows-x86_64-$ver.tar.gz"
        $arc = "$TorDir\tor.tar.gz"
        Write-Info "Baixando Tor Expert Bundle..."
        try {
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            Invoke-WebRequest $url -OutFile $arc -UseBasicParsing
        } catch {
            Write-Err "Falha no download do Tor. Verifique: https://dist.torproject.org/torbrowser/"
            exit 1
        }
        Write-Info "Extraindo Tor..."
        tar -xzf $arc -C $TorDir
        Remove-Item $arc -Force
        New-Item -ItemType Directory -Path "$TorDir\data" -Force | Out-Null
    } else { Write-Warn "Tor ja instalado — pulando." }

    # ── tun2socks ──────────────────────────────────────────────────────────────
    if (!(Test-Path $TunExe)) {
        Write-Info "Baixando tun2socks..."
        $tunUrl = "https://github.com/xjasonlyu/tun2socks/releases/latest/download/tun2socks-windows-amd64.zip"
        $tunZip = "$TorDir\tun2socks.zip"
        try {
            Invoke-WebRequest $tunUrl -OutFile $tunZip -UseBasicParsing
            Expand-Archive $tunZip -DestinationPath $TorDir -Force
            # renomeia para nome fixo
            $bin = Get-ChildItem $TorDir -Filter "tun2socks*.exe" | Select-Object -First 1
            if ($bin -and $bin.Name -ne "tun2socks.exe") {
                Rename-Item $bin.FullName "tun2socks.exe"
            }
            Remove-Item $tunZip -Force
        } catch {
            Write-Err "Falha no download do tun2socks. Baixe manualmente:"
            Write-Warn "  https://github.com/xjasonlyu/tun2socks/releases"
        }
    } else { Write-Warn "tun2socks ja instalado — pulando." }

    # ── WinTun DLL ─────────────────────────────────────────────────────────────
    if (!(Test-Path $WintunDll)) {
        Write-Info "Baixando WinTun (driver TUN)..."
        $wintunUrl = "https://www.wintun.net/builds/wintun-0.14.1.zip"
        $wintunZip = "$TorDir\wintun.zip"
        try {
            Invoke-WebRequest $wintunUrl -OutFile $wintunZip -UseBasicParsing
            $tmpDir = "$TorDir\wintun-tmp"
            Expand-Archive $wintunZip -DestinationPath $tmpDir -Force
            # Pega a DLL correta para x64
            $dll = Get-ChildItem $tmpDir -Recurse -Filter "wintun.dll" |
                   Where-Object { $_.FullName -match "amd64" } | Select-Object -First 1
            if (!$dll) {
                $dll = Get-ChildItem $tmpDir -Recurse -Filter "wintun.dll" | Select-Object -First 1
            }
            if ($dll) {
                Copy-Item $dll.FullName $WintunDll -Force
            }
            Remove-Item $tmpDir -Recurse -Force
            Remove-Item $wintunZip -Force
        } catch {
            Write-Err "Falha no download do WinTun."
            Write-Warn "  Baixe manualmente em https://www.wintun.net e copie wintun.dll para $TorDir"
        }
    } else { Write-Warn "WinTun ja instalado — pulando." }

    # ── Tor Browser ────────────────────────────────────────────────────────────
    if (!(Test-Path $TorBrowserExe)) {
        Write-Info "Buscando versao mais recente do Tor Browser..."
        $tbInstaller = "$TorDir\torbrowser-install.exe"
        $tbDir       = "$TorDir\tor-browser"
        try {
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

            # Varre diretorios do dist em ordem decrescente — sempre pega a mais recente com instalador Windows
            $distPage = Invoke-WebRequest "https://dist.torproject.org/torbrowser/" -UseBasicParsing -TimeoutSec 15
            $versions = [regex]::Matches($distPage.Content, 'href="(\d+\.\d+\.\d+)/"') |
                        ForEach-Object { $_.Groups[1].Value } |
                        Sort-Object { [version]$_ } -Descending

            $tbUrl = $null
            foreach ($tbVer in $versions) {
                try {
                    $dirPage = Invoke-WebRequest "https://dist.torproject.org/torbrowser/$tbVer/" -UseBasicParsing -TimeoutSec 10
                    # Pega qualquer instalador .exe para Windows x64
                    $tbFile = [regex]::Match($dirPage.Content, 'href="([^"]*(?:win64|windows-x86_64)[^"]*\.exe)"').Groups[1].Value
                    if ($tbFile) {
                        $tbUrl = "https://dist.torproject.org/torbrowser/$tbVer/$tbFile"
                        Write-Info "Versao mais recente: $tbVer — $tbFile"
                        break
                    }
                } catch {}
            }

            if (!$tbUrl) {
                # Debug: mostra as 3 versoes mais recentes encontradas
                Write-Warn "Versoes encontradas no dist: $(($versions | Select-Object -First 3) -join ', ')"
                throw "Instalador Windows nao encontrado. Verifique https://dist.torproject.org/torbrowser/"
            }

            Write-Info "Baixando: $tbUrl"
            Invoke-WebRequest $tbUrl -OutFile $tbInstaller -UseBasicParsing
            Write-Info "Instalando Tor Browser..."
            Start-Process $tbInstaller -ArgumentList "/S", "/D=$tbDir" -Wait
            Remove-Item $tbInstaller -Force -ErrorAction SilentlyContinue

            if (Test-Path $TorBrowserExe) {
                Write-OK "Tor Browser instalado."
            } elseif (Test-Path "$env:LOCALAPPDATA\Tor Browser\Browser\firefox.exe") {
                Write-OK "Tor Browser instalado em LOCALAPPDATA."
            } else {
                Write-Warn "Instalacao concluida. Tor Browser nao encontrado em $tbDir — verifique manualmente."
            }
        } catch {
            Write-Err "Falha ao instalar Tor Browser: $_"
            Write-Warn "Baixe manualmente em https://www.torproject.org/download/"
        }
    } else { Write-Warn "Tor Browser ja instalado — pulando." }

    # ── torrc ──────────────────────────────────────────────────────────────────
    $torrc = @"
SocksPort $SocksPort
ControlPort 9051
DNSPort $DNSPort
Log notice file $LogTor
DataDirectory $TorDir\data
ExitPolicy reject *:*
"@
    [System.IO.File]::WriteAllText($TorrcPath, $torrc, (New-Object System.Text.UTF8Encoding $false))

    Write-OK "Instalacao concluida em $TorDir"
    Write-Warn "Proximos passos:"
    Write-Host "  .\TorProxy-Win.ps1 -Action start       # proxy basico"
    Write-Host "  .\TorProxy-Win.ps1 -Action starttun    # FULL (todo o trafego)"
}

# ─── PROXY BASICO (WinINET — navegadores e maioria dos apps) ──────────────────
function Start-BasicProxy {
    Start-FullTun
    Open-TorBrowser

    $publicIp = & curl.exe --proxy socks5h://127.0.0.1:$SocksPort --max-time 8 -s https://ifconfig.me 2>$null
    if (!$publicIp) { $publicIp = "obtendo..." }

    Write-Host ""
    Write-Host "  ══════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "  Tor ativo   IP de saida : $publicIp" -ForegroundColor Green
    Write-Host "  ══════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""

    try {
        while ($true) { Start-Sleep -Seconds 5 }
    } finally {
        Write-Host ""
        Write-Info "Desconectando e restaurando rede..."
        Stop-All
    }
}

# ─── PROXY COMPLETO via tun2socks ─────────────────────────────────────────────
function Start-FullTun {
    if (!(Test-Path $TunExe))   { Write-Err "tun2socks nao encontrado. Execute -Action install."; exit 1 }
    if (!(Test-Path $WintunDll)) { Write-Err "wintun.dll nao encontrada. Execute -Action install."; exit 1 }

    # Copia wintun.dll para o diretorio de trabalho do tun2socks (exigido)
    $dst = Split-Path $TunExe
    if (!(Test-Path "$dst\wintun.dll")) {
        Copy-Item $WintunDll "$dst\wintun.dll" -Force
    }

    Start-TorProcess

    Write-Info "Coletando IPs dos reles Tor para roteamento direto..."
    Start-Sleep -Seconds 3
    $torPID = (Get-Process tor -ErrorAction SilentlyContinue | Select-Object -First 1).Id
    $relayIPs = @()
    if ($torPID) {
        $relayIPs = Get-NetTCPConnection -ErrorAction SilentlyContinue |
                    Where-Object {
                        $_.OwningProcess -eq $torPID -and
                        $_.State -eq "Established" -and
                        $_.RemoteAddress -notmatch "^(127\.|0\.|::)"
                    } | Select-Object -ExpandProperty RemoteAddress -Unique
    }

    # Gateway real atual
    $realRoute = Get-RealGateway
    if (!$realRoute) { Write-Err "Nao foi possivel detectar gateway. Verifique a rede."; exit 1 }
    $realGW  = $realRoute.NextHop
    $realIdx = $realRoute.InterfaceIndex
    $realIf  = (Get-NetAdapter -InterfaceIndex $realIdx -ErrorAction SilentlyContinue).Name

    Write-Info "Gateway real: $realGW (interface: $realIf)"

    # Inicia tun2socks em segundo plano
    Write-Info "Iniciando tun2socks..."
    $tunArgs = "-device tun://$TunName -proxy socks5://127.0.0.1:$SocksPort -loglevel warning"
    Start-Process -FilePath $TunExe -ArgumentList $tunArgs -WindowStyle Hidden -WorkingDirectory $TorDir

    Start-Sleep -Seconds 4

    # Configura IP na interface TUN
    Write-Info "Configurando interface TUN..."
    netsh interface ip set address "$TunName" static $TunIP $TunMask | Out-Null

    # ── Roteamento ─────────────────────────────────────────────────────────────
    # Rotas diretas para IPs dos reles Tor (evita loop)
    $savedRoutes = @()
    foreach ($ip in $relayIPs) {
        route add $ip mask 255.255.255.255 $realGW | Out-Null
        $savedRoutes += $ip
    }

    # Rota direta para o gateway local e rede local
    $localNet = ($realGW -replace "\.\d+$", ".0")
    route add $localNet mask 255.255.255.0 $realGW | Out-Null

    # Redireciona todo o resto pelo TUN (mais especifico que 0.0.0.0/0)
    route add 0.0.0.0     mask 128.0.0.0 $TunGW | Out-Null   # 0.0.0.0/1
    route add 128.0.0.0   mask 128.0.0.0 $TunGW | Out-Null   # 128.0.0.0/1

    # DNS via Tor (127.0.0.1:5353 → redirecionar porta 53 nao e trivial no Windows)
    # Configura DNS do adaptador TUN para usar 127.0.0.1 (Tor DNS)
    netsh interface ip set dns "$TunName" static 127.0.0.1 | Out-Null
    Set-DnsClientServerAddress -InterfaceIndex $realIdx -ServerAddresses ("127.0.0.1") -ErrorAction SilentlyContinue

    # Salva rotas para remocao posterior
    $allRoutes = @($savedRoutes) + @($localNet)
    [System.IO.File]::WriteAllLines($RouteFile, $allRoutes, (New-Object System.Text.UTF8Encoding $false))

    Apply-WinINETProxy
    Apply-EnvVars

    Write-OK "MODO COMPLETO ativo — todo o trafego TCP/UDP roteado pelo Tor."
    Write-Warn "DNS configurado via Tor (porta $DNSPort)."
    Show-VerifyCommands
}

# ─── PARAR ────────────────────────────────────────────────────────────────────
function Stop-All {
    Write-Info "Parando tun2socks e Tor..."

    # Remove rotas dos reles salvas
    if (Test-Path $RouteFile) {
        Get-Content $RouteFile | ForEach-Object {
            route delete $_ mask 255.255.255.255 2>$null
            route delete $_ mask 255.255.255.0   2>$null
        }
        Remove-Item $RouteFile -Force
    }
    route delete 0.0.0.0   mask 128.0.0.0 2>$null
    route delete 128.0.0.0 mask 128.0.0.0 2>$null

    # Restaura DNS
    $realIdx = (Get-RealGateway).InterfaceIndex
    if ($realIdx) {
        Set-DnsClientServerAddress -InterfaceIndex $realIdx -ResetServerAddresses -ErrorAction SilentlyContinue
    }

    Get-Process -Name "tun2socks" -ErrorAction SilentlyContinue | Stop-Process -Force
    Get-Process -Name "tor"       -ErrorAction SilentlyContinue | Stop-Process -Force

    Remove-WinINETProxy
    Remove-EnvVars

    Write-OK "Proxy desativado. Conexao direta restaurada."
}

# ─── STATUS ───────────────────────────────────────────────────────────────────
function Show-Status {
    $isTor  = !!(Get-Process tor        -ErrorAction SilentlyContinue)
    $isTun  = !!(Get-Process tun2socks  -ErrorAction SilentlyContinue)
    $proxyOn = (Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings").ProxyEnable
    $bridgeStatus = if ((Test-Path $TorrcPath) -and ((Get-Content $TorrcPath -Raw) -match "UseBridges 1")) {
        if ((Get-Content $TorrcPath -Raw) -match "meek") { "meek-azure" } else { "ativo" }
    } else { "desativado" }
    $exitCountryStatus = if ((Test-Path $TorrcPath) -and ((Get-Content $TorrcPath -Raw) -match "ExitNodes \{(\w+)\}")) {
        $Matches[1]
    } else { "qualquer" }

    Write-Host ""
    Write-Host "══════════════════════════════" -ForegroundColor Cyan
    Write-Host "  TorProxy-Win  STATUS" -ForegroundColor Cyan
    Write-Host "══════════════════════════════" -ForegroundColor Cyan
    Write-Host "  Tor processo  : $(if ($isTor)  { 'RODANDO' } else { 'PARADO'   })" -ForegroundColor $(if ($isTor)   { 'Green' } else { 'Red' })
    Write-Host "  tun2socks     : $(if ($isTun)  { 'RODANDO' } else { 'PARADO'   })" -ForegroundColor $(if ($isTun)   { 'Green' } else { 'Red' })
    Write-Host "  WinINET proxy : $(if ($proxyOn){ 'ATIVO'   } else { 'INATIVO'  })" -ForegroundColor $(if ($proxyOn) { 'Green' } else { 'Red' })
    Write-Host "  Bridge        : $bridgeStatus" -ForegroundColor $(if ($bridgeStatus -ne 'desativado') { 'Yellow' } else { 'Gray' })
    Write-Host "  Pais de saida : $exitCountryStatus" -ForegroundColor $(if ($exitCountryStatus -ne 'qualquer') { 'Yellow' } else { 'Gray' })
    Write-Host "  SOCKS5        : 127.0.0.1:$SocksPort"
    Write-Host "  DNS via Tor   : 127.0.0.1:$DNSPort"
    Write-Host "  Dir dados     : $TorDir"
    Write-Host ""
}

# ─── DESINSTALACAO ────────────────────────────────────────────────────────────
function Uninstall-All {
    Stop-All
    if (Test-Path $TorDir) {
        Remove-Item $TorDir -Recurse -Force
        Write-OK "Tudo removido."
    }
}

# ─── Funcoes internas ─────────────────────────────────────────────────────────
function Start-TorProcess {
    if (!(Test-Path $TorExe)) {
        Write-Info "Tor nao encontrado. Instalando automaticamente..."
        Install-All
    }
    if (Get-Process tor -ErrorAction SilentlyContinue) {
        Write-Info "Reiniciando Tor com nova configuracao..."
        Get-Process tor -ErrorAction SilentlyContinue | Stop-Process -Force
        Start-Sleep -Seconds 2
    }

    # Sempre regenera o torrc para garantir encoding e portas corretas
    $torrcContent = @"
SocksPort $SocksPort
ControlPort 9051
DNSPort $DNSPort
Log notice file $LogTor
DataDirectory $TorDir\data
GeoIPFile $TorDir\data\geoip
GeoIPv6File $TorDir\data\geoip6
ExitPolicy reject *:*
"@

    if ($ExitCountry -ne "") {
        $cc = $ExitCountry.ToUpper()
        Write-Info "Forcando saida pelo pais: $cc"
        $torrcContent += @"

ExitNodes {$cc}
StrictNodes 1
"@
    }

    [System.IO.File]::WriteAllText($TorrcPath, $torrcContent, (New-Object System.Text.UTF8Encoding $false))

    Write-Info "Iniciando Tor..."
    Start-Process $TorExe -ArgumentList "-f `"$TorrcPath`"" -WindowStyle Hidden

    $elapsed = 0; $timeout = 90
    Write-Host "[*] Aguardando bootstrap do Tor" -NoNewline -ForegroundColor Cyan
    while ($elapsed -lt $timeout) {
        Start-Sleep -Seconds 2; $elapsed += 2
        Write-Host "." -NoNewline
        if ((Test-Path $LogTor) -and ((Get-Content $LogTor -Raw) -match "100%")) { break }
    }
    Write-Host ""
    if ($elapsed -ge $timeout) { Write-Warn "Bootstrap demorou mais que o esperado — continuando mesmo assim. Veja: $LogTor" }
    Write-OK "Tor conectado."
}

function Apply-WinINETProxy {
    $r = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings"
    Set-ItemProperty $r ProxyEnable  1
    Set-ItemProperty $r ProxyServer  "socks=127.0.0.1:$SocksPort"
    Set-ItemProperty $r ProxyOverride "localhost;127.*;10.*;192.168.*;<local>"
    # Notifica WinInet
    Add-Type -TypeDefinition @"
using System; using System.Runtime.InteropServices;
public class WI {
  [DllImport("wininet.dll")]
  public static extern bool InternetSetOption(IntPtr h,int o,IntPtr b,int l);
}
"@ -ErrorAction SilentlyContinue
    [WI]::InternetSetOption([IntPtr]::Zero,39,[IntPtr]::Zero,0) 2>$null
    [WI]::InternetSetOption([IntPtr]::Zero,37,[IntPtr]::Zero,0) 2>$null
}

function Remove-WinINETProxy {
    $r = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings"
    Set-ItemProperty $r ProxyEnable 0
}

function Send-NewNym {
    try {
        $client = New-Object System.Net.Sockets.TcpClient("127.0.0.1", 9051)
        $stream  = $client.GetStream()
        $writer  = New-Object System.IO.StreamWriter($stream)
        $reader  = New-Object System.IO.StreamReader($stream)
        $writer.AutoFlush = $true
        $writer.WriteLine('AUTHENTICATE ""')
        $reader.ReadLine() | Out-Null
        $writer.WriteLine("SIGNAL NEWNYM")
        $reader.ReadLine() | Out-Null
        $client.Close()
    } catch { Write-Warn "Nao foi possivel enviar NEWNYM. Tor control port acessivel?" }
}

function Open-TorBrowser {
    $paths = @(
        $TorBrowserExe,
        "$env:LOCALAPPDATA\Tor Browser\Browser\firefox.exe",
        "$env:USERPROFILE\Desktop\Tor Browser\Browser\firefox.exe",
        "$env:USERPROFILE\Downloads\Tor Browser\Browser\firefox.exe",
        "C:\Tor Browser\Browser\firefox.exe",
        "$env:ProgramFiles\Tor Browser\Browser\firefox.exe"
    )
    $torBrowser = $paths | Where-Object { Test-Path $_ } | Select-Object -First 1

    if (!$torBrowser) {
        Write-Warn "Tor Browser nao encontrado."
        Write-Warn "Baixe em: https://www.torproject.org/download/"
        Write-OK "Todo o trafego do Windows ja esta roteado pelo Tor. Abra qualquer browser."
        return
    }

    Write-Info "Abrindo Tor Browser..."
    Start-Process $torBrowser
    Write-OK "Tor Browser aberto. Todo o trafego do Windows tambem passa pelo Tor."
}

function Find-GoogleCircuit {
    param([int]$MaxAttempts = 30)

    if (!(Get-Process tor -ErrorAction SilentlyContinue) -and !(netstat -an | Select-String ":9050")) {
        Write-Err "Tor nao esta rodando. Execute -Action start primeiro."
        exit 1
    }

    Write-Info "Procurando exit node nao bloqueado pelo Google (max $MaxAttempts tentativas)..."
    Write-Info "Cada troca leva ~10s para o circuito ser construido."
    Write-Host ""

    for ($i = 1; $i -le $MaxAttempts; $i++) {
        Write-Host "  [$i/$MaxAttempts] Testando circuito atual..." -NoNewline -ForegroundColor Cyan

        $response = & curl.exe --proxy socks5h://127.0.0.1:$SocksPort `
                               --max-time 10 -s -L `
                               -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/124.0 Safari/537.36" `
                               "https://www.google.com/search?q=test" 2>$null

        $blocked = $response -match "captcha|unusual traffic|automated queries|sorry|not available|detected unusual"
        $ok      = $response -match "<title>" -and -not $blocked

        if ($ok) {
            Write-Host " FUNCIONOU!" -ForegroundColor Green
            Write-Host ""
            Write-OK "Exit node livre encontrado na tentativa $i."
            Start-ChromeTor
            return
        }

        $motivo = if ($blocked) { "captcha/bloqueio detectado" } elseif (!$response) { "sem resposta" } else { "resposta invalida" }
        Write-Host " $motivo. Trocando..." -ForegroundColor Yellow
        Send-NewNym
        Start-Sleep -Seconds 12
    }

    Write-Err "Nao foi possivel encontrar exit node livre apos $MaxAttempts tentativas."
    Write-Warn "Tente novamente mais tarde ou use -ExitCountry para forcar um pais especifico."
}

function Apply-EnvVars {
    $p = "socks5://127.0.0.1:$SocksPort"
    foreach ($v in @("ALL_PROXY","HTTP_PROXY","HTTPS_PROXY")) {
        [System.Environment]::SetEnvironmentVariable($v, $p, "User")
        Set-Item "Env:\$v" $p
    }
}

function Remove-EnvVars {
    foreach ($v in @("ALL_PROXY","HTTP_PROXY","HTTPS_PROXY")) {
        [System.Environment]::SetEnvironmentVariable($v, $null, "User")
        Remove-Item "Env:\$v" -ErrorAction SilentlyContinue
    }
}

function Show-VerifyCommands {
    Write-Host ""
    Write-Host "  Verificar IP (sem Tor): curl https://ifconfig.me" -ForegroundColor White
    Write-Host "  Verificar via Tor     : curl --socks5 127.0.0.1:$SocksPort https://check.torproject.org/api/ip" -ForegroundColor White
    Write-Host "  Parar tudo            : .\TorProxy-Win.ps1 -Action stop" -ForegroundColor White
    Write-Host ""
}

# ─── Entry point ──────────────────────────────────────────────────────────────
Show-Banner

switch ($Action.ToLower()) {
    "install"   { Install-All }
    "start"     { Start-BasicProxy }

    "starttun"  { Start-FullTun }

    "stop"      { Stop-All }

    "status"    { Show-Status }

    "findgoogle" { Find-GoogleCircuit }

    "uninstall" { Uninstall-All }

    default {
        $w = 64
        $line = '─' * $w
        Write-Host "  ┌$line┐" -ForegroundColor DarkCyan
        Write-Host "  │" -NoNewline -ForegroundColor DarkCyan
        Write-Host ("  {0,-62}  " -f "COMANDOS DISPONIVEIS") -NoNewline -ForegroundColor Yellow
        Write-Host "│" -ForegroundColor DarkCyan
        Write-Host "  ├$line┤" -ForegroundColor DarkCyan

        $cmds = @(
            @{ Cmd="-Action start                "; Desc="Inicia — instala se necessario e roteia todo o trafego pelo Tor" }
            @{ Cmd="-Action start -ExitCountry CH"; Desc="Inicia com saida forcada por pais" }
            @{ Cmd="-Action findgoogle           "; Desc="Troca circuito ate achar exit node livre no Google" }
            @{ Cmd="-Action status               "; Desc="Exibe estado atual" }
            @{ Cmd="-Action uninstall            "; Desc="Remove tudo do sistema" }
        )

        foreach ($cmd in $cmds) {
            Write-Host "  │  " -NoNewline -ForegroundColor DarkCyan
            Write-Host $cmd.Cmd -NoNewline -ForegroundColor Green
            Write-Host "  $($cmd.Desc)" -NoNewline -ForegroundColor White
            $pad = $w - 4 - $cmd.Cmd.Length - 2 - $cmd.Desc.Length
            Write-Host (" " * [Math]::Max(0,$pad)) -NoNewline
            Write-Host "│" -ForegroundColor DarkCyan
        }

        Write-Host "  └$line┘" -ForegroundColor DarkCyan
        Write-Host ""
    }
}
