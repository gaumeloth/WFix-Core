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

function Check-ExitCode($label) {
    if ($LASTEXITCODE -ne 0) {
      $msg = "WARNING: $label ha restituito codice $LASTEXITCODE"
      Write-Log $msg
      $global:FailureMessages += $msg
    }
  }

# ╔═════[ SETUP ]═════╗
$LogDir = "$env:USERPROFILE\Desktop\WFixLogs"
$MasterLog = "$LogDir\repair-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
$global:FailureMessages = @()
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
    "5" = "Esportazione EventLog"
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
    $choice = Read-Host "Scelta (default 1)"
    if (-not $choice) { $choice = 1 }
    $drive = "$($drives[[int]$choice - 1]):"
    $log = "$LogDir\chkdsk.log"
    Start-Process cmd.exe "/c echo y| chkdsk $drive /f /r > `"$log`"" -Wait
    Check-ExitCode "CHKDSK"
    Write-Log "CHKDSK completato. Log: $log"
}

if ($selectedSteps -contains "2") {
    Write-Log "[2] Avvio DISM..."
    dism /Online /Cleanup-Image /ScanHealth >> "$MasterLog" 2>&1
    Check-ExitCode "DISM ScanHealth"
    dism /Online /Cleanup-Image /RestoreHealth >> "$MasterLog" 2>&1
    Check-ExitCode "DISM RestoreHealth"
    Write-Log "DISM completato."
}

if ($selectedSteps -contains "3") {
    Write-Log "[3] Avvio SFC..."
    sfc /scannow >> "$MasterLog" 2>&1
    Check-ExitCode "SFC"
    Write-Log "SFC completato."
}

if ($selectedSteps -contains "4") {
    Write-Log "[4] Ripristino rete..."
    netsh winsock reset >> "$MasterLog" 2>&1
    Check-ExitCode "netsh winsock reset"
    netsh int ip reset >> "$MasterLog" 2>&1
    Check-ExitCode "netsh int ip reset"
    Write-Log "Stack di rete ripristinato."
}

if ($selectedSteps -contains "5") {
    Export-EventLogs
}

# ╔═════[ CONCLUSIONE ]═════╗
Write-Log "=== Script terminato ==="
Write-Host "`n✅ Tutte le operazioni selezionate sono state completate."
Write-Host "📄 Log master salvato in: `"$MasterLog`""
Write-Host "📂 Cartella completa: $LogDir"

if (Prompt-YesNo "Vuoi aprire la cartella dei log ora?") {
    Start-Process "explorer.exe" $LogDir
}
