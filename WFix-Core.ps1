# WFix-Core.ps1
# Versione interattiva con integrazione EventLog
# Autore: Gaumeloth

function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[$timestamp] $Message"
    Write-Output $line
    Add-Content -Path $global:MasterLog -Value $line
}

function Export-EventLogs {
    $eventsDir = "$LogDir\EventLogs"
    New-Item -ItemType Directory -Path $eventsDir -Force | Out-Null
    Write-Log "Esportazione EventLog..."

    Get-WinEvent -LogName "System" -MaxEvents 500 | Export-Clixml -Path "$eventsDir\System.xml"
    Get-WinEvent -LogName "Application" -MaxEvents 500 | Export-Clixml -Path "$eventsDir\Application.xml"
    Get-WinEvent -LogName "Microsoft-Windows-DISM/Operational" -MaxEvents 200 -ErrorAction SilentlyContinue | Export-Clixml -Path "$eventsDir\DISM.xml"
    Get-WinEvent -LogName "Microsoft-Windows-WindowsUpdateClient/Operational" -MaxEvents 200 -ErrorAction SilentlyContinue | Export-Clixml -Path "$eventsDir\WindowsUpdate.xml"
    Write-Log "EventLog salvati in $eventsDir"
}

function Prompt-YesNo($msg) {
    do {
        $choice = Read-Host "$msg (S/n)"
    } while ($choice -notmatch '^[SsNn]$')
    return $choice -match '^[Ss]$'
}

function Check-ExitCode($label, [int]$exitCode = $LASTEXITCODE) {
    if ($exitCode -ne 0) {
      $msg = "WARNING: $label ha restituito codice $exitCode"
      Write-Log $msg
      $script:FailureMessages += $msg
    }
  }

function Test-DriveValid {
    param([string]$Drive)
    $d = $Drive.Trim()
    if ($d -notmatch '^[A-Za-z]:$') { return $false }
    return (Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Name -eq $d.TrimEnd(':') }).Count -gt 0
}

function Test-SafePath {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return $false }
    if ($Path -match "\.\." -or $Path -match "[|&]") { return $false }
    return $true
}

# ╔═════[ SETUP ]═════╗
$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$LogDir = "$env:USERPROFILE\Desktop\WFixLogs\$timestamp"
$MasterLog = "$LogDir\repair.log"
# Log individual tools
$dismLog = "$LogDir\dism.log"
$sfcLog = "$LogDir\sfc.log"
$netshLog = "$LogDir\netsh.log"
$driver0Log = "$LogDir\driver0ps.log"
$driversListLog = "$LogDir\drivers.txt"
$script:FailureMessages = @()
New-Item -ItemType Directory -Path $LogDir -Force | Out-Null

if (-not ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(`
    [Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "Riavvio lo script con privilegi elevati..."
    Start-Process powershell.exe "-ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

Write-Log "=== Riparazione di Windows Interattiva Avviata ==="

# ╔═════[ MENU INTERATTIVO ]═════╗
$steps = @{
    "1" = "CHKDSK (controllo disco)"
    "2" = "DISM (ripara immagine Windows)"
    "3" = "SFC (verifica file di sistema)"
    "4" = "NETSH (reset rete TCP/IP)"
    "5" = "Aggiorna driver"
}
Write-Host "`nSeleziona gli strumenti da eseguire:"
$selectedSteps = @()

foreach ($key in $steps.Keys) {
    if (Prompt-YesNo "$($steps[$key])?") {
        $selectedSteps += $key
    }
}

# ╔═════[ ESECUZIONE MODULI ]═════╗
if ($selectedSteps -contains "1") {
    Write-Log "[1] Avvio CHKDSK..."
    $drives = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Free -gt 0 } | Select-Object -ExpandProperty Name
    Write-Host "`nSeleziona il drive da controllare:"
    for ($i = 0; $i -lt $drives.Count; $i++) {
        $num = $i + 1
        Write-Host "$num. $($drives[$i]):"
    }
    $index = 0
    do {
      $input = Read-Host "Scelta (default 1)"
      if (-not $input) {$input = '1'}
      if ([int]::TryParse($input, [ref]$index) -and $index -ge 1 -and $index -le $drives.Count) {
        break
      } else {
        Write-Host "Input non valido. Inserisci un numero tra 1 e $($drives.Count)." -ForegroundColor red
      }
    } while ($true)
    $drive = "$drives[$index - 1]:"
    if (Test-DriveValid $drive) {
        $log = "$LogDir\chkdsk.log"
        'Y' | & chkdsk.exe $drive '/f' '/r' 2>&1 | Tee-Object -FilePath $log
        $exitCode = $LASTEXITCODE
        Check-ExitCode "CHKDSK" $exitCode
        Write-Log "CHKDSK completato. Log: $log"
    } else {
        Write-Log "Drive non valido: $drive"
    }
}

if ($selectedSteps -contains "2") {
    Write-Log "[2] Avvio DISM..."
    dism /Online /Cleanup-Image /ScanHealth 2>&1 | Tee-Object -FilePath $dismLog -Append
    Check-ExitCode "DISM ScanHealth"
    dism /Online /Cleanup-Image /RestoreHealth 2>&1 | Tee-Object -FilePath $dismLog -Append
    Check-ExitCode "DISM RestoreHealth"
    Write-Log "DISM completato. Log: $dismLog"
}

if ($selectedSteps -contains "3") {
    Write-Log "[3] Avvio SFC..."
    sfc /scannow 2>&1 | Tee-Object -FilePath $sfcLog -Append
    Check-ExitCode "SFC"
    Write-Log "SFC completato. Log: $sfcLog"
}

if ($selectedSteps -contains "4") {
    Write-Log "[4] Ripristino rete..."
    netsh winsock reset 2>&1 |  Tee-Object -FilePath $netshLog -Append
    Check-ExitCode "netsh winsock reset"
    netsh int ip reset 2>&1 | Tee-Object -FilePath $netshLog -Append
    Check-ExitCode "netsh int ip reset"
    Write-Log "Stack di rete ripristinato. Log: $netshLog"
}

if ($selectedSteps -contains "5") {
    Write-Log "[5] Verifica driver installati..."
    try {
        Get-PnpDevice | Sort-Object FriendlyName | Out-File -FilePath $driversListLog
        Write-Log "Elenco driver salvato in $driversListLog"
    } catch {
        Write-Log "Errore durante la generazione dell'elenco driver: $_"
    }

    if (Prompt-YesNo "Vuoi cercare i driver tramite Windows Update?") {
        if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {
            Write-Log "Installazione modulo PSWindowsUpdate..."
            Install-Module -Name PSWindowsUpdate -Force -Scope CurrentUser -ErrorAction SilentlyContinue
        }
        Import-Module PSWindowsUpdate -ErrorAction SilentlyContinue
        if (Get-Command Get-WindowsUpdate -ErrorAction SilentlyContinue) {
            Write-Log "Ricerca e installazione driver..."
            Get-WindowsUpdate -MicrosoftUpdate -Category Drivers -AcceptAll -Install -AutoReboot:$false 2>&1 | Tee-Object -FilePath $driver0Log -Append
            Check-ExitCode "WindowsUpdate Driver Install"
            Write-Log "Aggiornamento driver completato. Log: $driver0Log"
        } else {
            Write-Log "Modulo PSWindowsUpdate non disponibile."
        }
    } else {
        $path = Read-Host "Percorso file .inf o cartella driver (vuoto per saltare)"
        if ($path) {
            if (Test-SafePath $path) {
                Write-Log "Installazione driver da $path..."
                pnputil.exe /add-driver "$path" /install 2>&1 | Tee-Object -FilePath $driver0Log -Append
                Check-ExitCode "pnputil install"
                Write-Log "Driver installati da $path. Log: $driver0Log"
            } else {
                Write-Log "Percorso non valido o insicuro: $path"
                Write-Host "Percorso driver non valido. Operazione annullata." -ForegroundColor red
            }
        }
    }
}

Export-EventLogs

# ╔═════[ CONCLUSIONE ]═════╗
Write-Log "=== Script terminato ==="
if ($Script:FailureMessages.Count -gt 0) {
    Write-Log "=== Riepilogo errori ==="
    foreach ($msg in $Script:FailureMessages) {
        Write-Log $msg
    }
    Write-Host "`n⚠️ Problemi rilevati durante l'esecuzione:"
    foreach ($msg in $Script:FailureMessages) {
        Write-Host " - $msg"
    }
    Write-Host "Controlla il log principale per maggiori dettagli."
}
Write-Host "`n✅ Tutte le operazioni selezionate sono state completate."
Write-Host "📄 Log master salvato in: `"$MasterLog`""
Write-Host "📂 Cartella completa: $LogDir"

if (Prompt-YesNo "Vuoi aprire la cartella dei log ora?") {
    Start-Process "explorer.exe" $LogDir
}
