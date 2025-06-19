Write-Host @"
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::


       _______ _____ ____   _____                                 
      |__   __/ ____|___ \ / ____|                                
         | | | (___   __) | (___   ___ _ ____   _____ _ __        
         | |  \___ \ |__ < \___ \ / _ \ '__\ \ / / _ \ '__|       
         | |  ____) |___) |____) |  __/ |   \ V /  __/ |          
         |_| |_____/|____/|_____/ \___|_|  _ \_/ \___|_|          
     /\        | |        |_   _|         | |      | | |          
    /  \  _   _| |_ ___     | |  _ __  ___| |_ __ _| | | ___ _ __ 
   / /\ \| | | | __/ _ \    | | | '_ \/ __| __/ _` | | |/ _ \ '__|
  / ____ \ |_| | || (_) |  _| |_| | | \__ \ || (_| | | |  __/ |   
 /_/    \_\__,_|\__\___/  |_____|_| |_|___/\__\__,_|_|_|\___|_|   
                                                                  
                                                                  

:::::::::::Effortless Teamspeak3 Server Installer for:::::::::::::
:::::::::::::::::::Windows, Mac and Linux.::::::::::::::::::::::::
::::::::::::::::https://github.com/ChocoJaYY::::::::::::::::::::::
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::


"@ -ForegroundColor Cyan

Start-Sleep -Seconds 2

# Elevation check - Need admin right to add firewall rules etc.
If (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "Restarting script with administrator privileges..."
    Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

# --- Installation Logic Below ---

$TS3_VERSION = "3.13.7"
$TS3_DIR = "C:\ts3server"
$TS3_URL = "https://files.teamspeak-services.com/releases/server/$TS3_VERSION/teamspeak3-server_win64-$TS3_VERSION.zip"
$ZIP_PATH = "$env:TEMP\ts3server.zip"

Write-Host "`nDownloading TeamSpeak 3 Server v$TS3_VERSION..."
Invoke-WebRequest -Uri $TS3_URL -OutFile $ZIP_PATH -UseBasicParsing

Write-Host "Extracting to $TS3_DIR..."
if (Test-Path $TS3_DIR) {
    $choice = Read-Host "Folder $TS3_DIR already exists. Overwrite (O), Upgrade (U), or Skip (S)?"
    switch ($choice.ToLower()) {
        "o" { Remove-Item $TS3_DIR -Recurse -Force }
        "u" { Copy-Item "$TS3_DIR\ts3server.ini" "$env:TEMP\ts3server.ini" -ErrorAction SilentlyContinue }
        "s" { Write-Host "Skipping install."; exit }
        default { Write-Host "Invalid choice."; exit 1 }
    }
}
New-Item -Path $TS3_DIR -ItemType Directory -Force | Out-Null

$sevenZip = Get-Command 7z.exe -ErrorAction SilentlyContinue
if ($sevenZip) {
    & 7z x $ZIP_PATH "-o$TS3_DIR" -y | Out-Null
    Write-Host "Extracted with 7-Zip."
} else {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::ExtractToDirectory($ZIP_PATH, $TS3_DIR)
    Write-Host "Extracted using built-in .NET."
}

$extractedSubfolder = Join-Path $TS3_DIR "teamspeak3-server_win64"
if (Test-Path "$extractedSubfolder\ts3server.exe") {
    Get-ChildItem -Path $extractedSubfolder | Move-Item -Destination $TS3_DIR -Force
    Remove-Item $extractedSubfolder -Recurse -Force
}

New-Item -Path "$TS3_DIR\.ts3server_license_accepted" -ItemType File -Force | Out-Null

if (Test-Path "$env:TEMP\ts3server.ini") {
    Move-Item "$env:TEMP\ts3server.ini" "$TS3_DIR\ts3server.ini"
    Write-Host "Restored old config file."
}

$StartScript = "$TS3_DIR\start_ts3.ps1"
$startScriptContent = @"
cd '$TS3_DIR'
Start-Process -FilePath 'ts3server.exe' -ArgumentList 'inifile=ts3server.ini' -WorkingDirectory '$TS3_DIR' -NoNewWindow
"@
$startScriptContent | Set-Content -Path $StartScript

$configContent = @"
default_voice_port=9987
query_port=10011
filetransfer_port=30033
logappend=1
"@
Set-Content -Path "$TS3_DIR\ts3server.ini" -Value $configContent

Write-Host "Created start script."

$autoStart = Read-Host "`nDo you want to autostart the server on boot? (Y/N)"
if ($autoStart -match '^(y|yes)$') {
    $taskName = "TeamSpeak3Server"
    $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -File `"$StartScript`""
    $trigger = New-ScheduledTaskTrigger -AtStartup
    $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -RunLevel Highest
    Register-ScheduledTask -Action $action -Trigger $trigger -Principal $principal -TaskName $taskName -Force
    Write-Host "Autostart task created."
}

if (Test-Path "$TS3_DIR\ts3server.exe") {
    Write-Host "`nStarting TeamSpeak 3 Server..."
    Start-Process -FilePath "$TS3_DIR\ts3server.exe" -ArgumentList "inifile=ts3server.ini" -WorkingDirectory $TS3_DIR
    Start-Sleep -Seconds 5
} else {
    Write-Host "ERROR: ts3server.exe not found in $TS3_DIR"
    exit 1
}

$logPath = "$TS3_DIR\logs"
$timeout = 0
while (!(Test-Path $logPath) -and ($timeout -lt 10)) {
    Start-Sleep -Seconds 1
    $timeout++
}

if (Test-Path $logPath) {
    $logFile = Get-ChildItem "$logPath" -Filter "*_1.log" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    $token = Select-String -Path $logFile.FullName -Pattern 'token=.*' | ForEach-Object { $_.Line -replace '.*token=', '' }
    $login = Select-String -Path $logFile.FullName -Pattern 'loginname=' | ForEach-Object { ($_ -split '"')[1] }
    $password = Select-String -Path $logFile.FullName -Pattern 'password=' | ForEach-Object { ($_ -split '"')[1] }

    $token | Set-Content "$TS3_DIR\ServerAdmin_Privilege_Key.txt"
    "${login}:${password}" | Set-Content "$TS3_DIR\Query_Login.txt"
} else {
    Write-Host "WARNING: Server logs not found after waiting. Credentials could not be extracted."
}

Write-Host "`nInstallation Complete!"
Write-Host "Saved to:"
Write-Host "   $TS3_DIR\ServerAdmin_Privilege_Key.txt"
Write-Host "   $TS3_DIR\Query_Login.txt"

$openFirewall = Read-Host "`nDo you want to open the required firewall ports for TeamSpeak 3? (Y/N)"
if ($openFirewall -match '^(y|yes)$') {
    Write-Host "Adding Windows Firewall rules..."
    New-NetFirewallRule -DisplayName "TeamSpeak 3 Voice" -Direction Inbound -Protocol UDP -LocalPort 9987 -Action Allow -Profile Any
    New-NetFirewallRule -DisplayName "TeamSpeak 3 Query" -Direction Inbound -Protocol TCP -LocalPort 10011 -Action Allow -Profile Any
    New-NetFirewallRule -DisplayName "TeamSpeak 3 File Transfer" -Direction Inbound -Protocol TCP -LocalPort 30033 -Action Allow -Profile Any
    Write-Host "Firewall rules added successfully."
} else {
    Write-Host "Skipping firewall configuration."
}

Write-Host "`nInstallation Successful! :-) Script will auto close in 5 seconds..."
Start-Sleep -Seconds 1
Write-Host "`nScript will auto close in 4 seconds..."
Start-Sleep -Seconds 1
Write-Host "`nScript will auto close in 3 seconds..."
Start-Sleep -Seconds 1
Write-Host "`nScript will auto close in 2 seconds..."
Start-Sleep -Seconds 1
Write-Host "`nScript will auto close now. Bye Bye :-)"
Start-Sleep -Seconds 1
exit
