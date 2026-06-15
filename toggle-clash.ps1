<#
.SYNOPSIS
    Toggle Clash Verge VPN on/off. No admin required.
.DESCRIPTION
    ON  = ensure Clash core running + enable system proxy
    OFF = disable system proxy (core stays idle, no admin needed)
.PARAMETER Action
    on | off | status
.PARAMETER SafeSecs
    Auto-restore proxy after N seconds when testing (0 = no safety net).
.EXAMPLE
    .\toggle-clash.ps1 status
    .\toggle-clash.ps1 on -SafeSecs 30
    .\toggle-clash.ps1 off
#>

param(
    [ValidateSet("on", "off", "status")]
    [string]$Action = "status",

    [int]$SafeSecs = 0
)

$installDir  = "I:\b"
$clashGui    = "$installDir\clash-verge.exe"
$mihomoCore  = "$installDir\verge-mihomo.exe"
$mihomoAlpha = "$installDir\verge-mihomo-alpha.exe"
$sysproxy    = "$installDir\resources\sysproxy.exe"
$configDir   = "$env:APPDATA\io.github.clash-verge-rev.clash-verge-rev"
$proxyServer = "127.0.0.1:7897"
$bypassList  = "localhost;127.*;192.168.*;10.*;172.16.*;172.17.*;172.18.*;172.19.*;172.20.*;172.21.*;172.22.*;172.23.*;172.24.*;172.25.*;172.26.*;172.27.*;172.28.*;172.29.*;172.30.*;172.31.*;<local>"
$backupFile  = "$env:TEMP\clash-proxy-backup.json"

# ===================== Proxy helpers =====================

function Get-ProxyStatus {
    try {
        $r = Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" -Name ProxyEnable, ProxyServer -ErrorAction Stop
        [PSCustomObject]@{ ProxyEnabled = [bool]$r.ProxyEnable; ProxyServer = $r.ProxyServer }
    } catch {
        [PSCustomObject]@{ ProxyEnabled = $false; ProxyServer = "" }
    }
}

function Enable-Proxy {
    Write-Host "[PROXY] Enabling -> $proxyServer"
    if (Test-Path $sysproxy) { & $sysproxy global $proxyServer $bypassList 2>&1 | Out-Null }
    Set-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" -Name ProxyEnable -Value 1 -Type DWord
    Set-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" -Name ProxyServer -Value $proxyServer -Type String
}

function Disable-Proxy {
    Write-Host "[PROXY] Disabling"
    if (Test-Path $sysproxy) { & $sysproxy set 1 2>&1 | Out-Null }
    Set-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" -Name ProxyEnable -Value 0 -Type DWord
}

function Test-Connectivity {
    try { $null = Invoke-WebRequest "http://www.baidu.com" -TimeoutSec 5 -UseBasicParsing; return $true } catch { return $false }
}

# ===================== Core process helpers =====================

function Get-ClashProcesses {
    Get-Process -Name "clash-verge","verge-mihomo","verge-mihomo-alpha" -ErrorAction SilentlyContinue
}

function Start-ClashCore {
    $running = Get-ClashProcesses
    if ($running) {
        Write-Host "[CORE] Already running: $(($running | ForEach-Object { "$($_.ProcessName):$($_.Id)" }) -join ', ')"
    } else {
        if (-not (Test-Path $clashGui)) {
            Write-Host "[CORE] ERROR: $clashGui not found"
            return $false
        }
        Write-Host "[CORE] Launching $clashGui ..."
        Start-Process $clashGui -WorkingDirectory $installDir -WindowStyle Minimized | Out-Null
    }

    Write-Host "[CORE] Waiting for port $proxyServer ..."
    $attempts = 0
    while ($attempts -lt 20) {
        Start-Sleep -Milliseconds 500
        if (netstat -ano 2>$null | Select-String "127.0.0.1:7897.*LISTENING") {
            Write-Host "[CORE] Ready (took $($attempts*0.5)s)"
            return $true
        }
        $attempts++
    }
    Write-Host "[CORE] Timeout waiting for port"
    return $false
}

function Stop-ClashCore {
    $gui = Get-Process -Name "clash-verge" -ErrorAction SilentlyContinue
    if ($gui) {
        Write-Host "[CORE] Closing GUI gracefully..."
        $gui.CloseMainWindow() | Out-Null
        Start-Sleep -Milliseconds 1500
        if (-not $gui.HasExited) {
            Write-Host "[CORE] GUI didn't close, leaving core (managed by service)"
        } else {
            Write-Host "[CORE] GUI closed"
        }
    }
    $core = Get-Process -Name "verge-mihomo","verge-mihomo-alpha" -ErrorAction SilentlyContinue
    if ($core) {
        Write-Host "[CORE] Core still running (managed by service, will idle)"
    } else {
        Write-Host "[CORE] Core not running"
    }
}

# ===================== Safety net =====================

function Backup-ProxyState {
    $s = Get-ProxyStatus
    @{ ProxyEnable = [int]$s.ProxyEnabled; ProxyServer = $s.ProxyServer } | ConvertTo-Json | Set-Content $backupFile -Force
    Write-Host "[BACKUP] ProxyEnable=$($s.ProxyEnabled) Server=$($s.ProxyServer)"
}

function Start-SafetyNet {
    param([int]$Secs)
    Backup-ProxyState

    $code = 'param($bf) $b=Get-Content $bf -Raw|ConvertFrom-Json;Set-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" -Name ProxyEnable -Value ([int]$b.ProxyEnable) -Type DWord;Set-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" -Name ProxyServer -Value ([string]$b.ProxyServer) -Type String;Remove-Item $bf -Force -ErrorAction SilentlyContinue'
    $scriptPath = "$env:TEMP\clash-restore-safety.ps1"
    $code | Set-Content $scriptPath -Force

    $watcher = Start-Process powershell -ArgumentList "-NoProfile -WindowStyle Hidden -Command Start-Sleep -Seconds $Secs; & `"$scriptPath`" -bf `"$backupFile`"; Remove-Item `"$scriptPath`" -Force" -PassThru
    Write-Host "[SAFETY] Watcher PID=$($watcher.Id) will restore in ${Secs}s"
    return @{ Watcher=$watcher; Script=$scriptPath }
}

function Stop-SafetyNet {
    param($Info)
    if ($Info.Watcher) { Stop-Process -Id $Info.Watcher.Id -Force -ErrorAction SilentlyContinue }
    if ($Info.Script)  { Remove-Item $Info.Script -Force -ErrorAction SilentlyContinue }
    Remove-Item $backupFile -Force -ErrorAction SilentlyContinue
    Write-Host "[SAFETY] Removed"
}

# ===================== Main =====================

switch ($Action) {
    "status" {
        $proxy = Get-ProxyStatus
        $core  = Get-ClashProcesses
        $gui   = Get-Process -Name "clash-verge" -ErrorAction SilentlyContinue
        $mihomoProc = Get-Process -Name "verge-mihomo","verge-mihomo-alpha" -ErrorAction SilentlyContinue

        if ($proxy.ProxyEnabled) {
            Write-Host "VPN: ON  (proxy active -> $($proxy.ProxyServer))"
        } else {
            Write-Host "VPN: OFF (direct connection)"
        }
        if ($gui)   { Write-Host "  GUI   : PID $($gui.Id)" }
        if ($mihomoProc) { Write-Host "  Core  : PID $($mihomoProc.Id) [listening]" } else { Write-Host "  Core  : not running" }
    }

    "on" {
        $safety = $null
        if ($SafeSecs -gt 0) { $safety = Start-SafetyNet -Secs $SafeSecs }

        $coreOk = Start-ClashCore
        if (-not $coreOk) {
            Write-Host "[ERROR] Failed to start Clash core"
            if ($safety) { Stop-SafetyNet $safety }
            exit 1
        }

        Enable-Proxy
        Write-Host "[DONE] VPN ON"

        if ($safety) {
            Start-Sleep -Seconds 3
            if (Test-Connectivity) {
                Write-Host "[TEST] Internet OK - keeping changes"
                Stop-SafetyNet $safety
            } else {
                Write-Host "[TEST] Internet FAILED! Auto-restore pending..."
            }
        }
    }

    "off" {
        $safety = $null
        if ($SafeSecs -gt 0) { $safety = Start-SafetyNet -Secs $SafeSecs }

        Disable-Proxy
        Write-Host "[DONE] VPN OFF"

        if ($safety) {
            Start-Sleep -Seconds 3
            if (Test-Connectivity) {
                Write-Host "[TEST] Internet OK - keeping changes"
                Stop-SafetyNet $safety
            } else {
                Write-Host "[TEST] Internet FAILED! Auto-restore pending..."
            }
        }
    }
}
