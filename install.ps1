# install_ts3-server.ps1
# Version: 1.0
# Windows TeamSpeak 3 Server Installer
# Requires: PowerShell 5+, 7-Zip (optional)

$TS3_VERSION = "3.13.7"
$TS3_DIR = "C:\ts3server"
$TS3_URL = "https://files.teamspeak-services.com/releases/server/$TS3_VERSION/teamspeak3-server_win64-$TS3_VERSION.zip"
$ZIP_PATH = "$env:TEMP\ts3server.zip"

Write-Host "`n📦 Downloading TeamSpeak 3 Server v$TS3_VERSION..."

Invoke-WebRequest -Uri $TS3_URL -OutFile $ZIP_PATH -UseBasicParsing

# Extract
Write-Host "📂 Extracting to $TS3_DIR..."

# Create destination
if (Test-Path $TS3_DIR) {
    $choice = Read-Host "⚠️ Folder $TS3_DIR already exists. Overwrite (O), Upgrade (U), or Skip (S)?"
    switch ($choice.ToLower()) {
        "o" { Remove-Item $TS3_DIR -Recurse -Force }
        "u" { Copy-Item "$TS3_DIR\ts3server.ini", "$env:TEMP\ts3server.ini" -ErrorAction SilentlyContinue }
        "s" { Write-Host "⏭️ Skipping install."; exit }
        default { Write-Host "❌ Invalid choice."; exit 1 }
    }
}
New-Item -Path $TS3_DIR -ItemType Directory -Force | Out-Null

# Check for 7-Zip
$sevenZip = Get-Command 7z.exe -ErrorAction SilentlyContinue
if ($sevenZip) {
    & 7z x $ZIP_PATH "-o$TS3_DIR" -y | Out-Null
    Write-Host "✅ Extracted with 7-Zip."
} else {
    # Native fallback
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::ExtractToDirectory($ZIP_PATH, $TS3_DIR)
    Write-Host "✅ Extracted using built-in .NET."
}

# License acceptance
New-Item -Path "$TS3_DIR\.ts3server_license_accepted" -ItemType File -Force | Out-Null

# Optional restore
if (Test-Path "$env:TEMP\ts3server.ini") {
    Move-Item "$env:TEMP\ts3server.ini" "$TS3_DIR\ts3server.ini"
    Write-Host "🔁 Restored old config file."
}

# Create start script
$StartScript = "$TS3_DIR\start_ts3.ps1"
@"
cd '$TS3_DIR'
Start-Process ts3server.exe -ArgumentList 'inifile=ts3server.ini' -NoNewWindow
"@ | Set-Content -Path $StartScript
Set-Content "$TS3_DIR\ts3server.ini" "default_voice_port=9987`nquery_port=10011`nfiletransfer_port=30033`nlogappend=1"
Write-Host "🚀 Created start script."

# Ask for autostart
$autoStart = Read-Host "`n🔁 Do you want to autostart the server on boot? (Y/N)"
if ($autoStart -match '^(y|yes)$') {
    $taskName = "TeamSpeak3Server"
    $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -File `"$StartScript`""
    $trigger = New-ScheduledTaskTrigger -AtStartup
    $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -RunLevel Highest
    Register-ScheduledTask -Action $action -Trigger $trigger -Principal $principal -TaskName $taskName -Force
    Write-Host "✅ Autostart task created."
}

# Start server
Write-Host "`n🟢 Starting TeamSpeak 3 Server..."
Start-Process "$TS3_DIR\ts3server.exe" -ArgumentList "inifile=ts3server.ini"
Start-Sleep -Seconds 5

# Parse log for credentials
$logFile = Get-ChildItem "$TS3_DIR\logs" -Filter "*_1.log" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
$token = Select-String -Path $logFile.FullName -Pattern 'token=.*' | ForEach-Object { $_.Line -replace '.*token=', '' }
$login = Select-String -Path $logFile.FullName -Pattern 'loginname=' | ForEach-Object { ($_ -split '"')[1] }
$password = Select-String -Path $logFile.FullName -Pattern 'password=' | ForEach-Object { ($_ -split '"')[1] }

# Save credentials
$token | Set-Content "$TS3_DIR\ServerAdmin_Privilege_Key.txt"
"$login:$password" | Set-Content "$TS3_DIR\Query_Login.txt"

# Output
Write-Host "`n🎉 Installation Complete!"
Write-Host "🔐 ServerAdmin Token: $token"
Write-Host "🛠️  Query Login: $login"
Write-Host "🔑 Query Pass: $password"
Write-Host "📁 Saved to:"
Write-Host "   $TS3_DIR\ServerAdmin_Privilege_Key.txt"
Write-Host "   $TS3_DIR\Query_Login.txt"
