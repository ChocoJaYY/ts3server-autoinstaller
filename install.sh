#!/bin/bash
# Name: install_ts3-server.sh
# Version: 3.1
# Updated: 2025-06-17

set -e

# === Config ===
TS3_USER="teamspeak3"
TS3_VER="${TS3_VER:-3.13.7}"

# === Detect OS ===
OS="$(uname)"
ARCH="$(uname -m)"
case "$OS" in
  "Linux")
    PLATFORM="linux"
    TS3_DIR="/opt/ts3server"
    SUDO="sudo"
    ;;
  "Darwin")
    PLATFORM="mac"
    TS3_DIR="$HOME/ts3server"
    SUDO=""
    ;;
  *)
    echo "❌ Unsupported OS: $OS"
    exit 1
    ;;
esac

# === Validate Arch ===
if [[ "$ARCH" != "x86_64" && "$ARCH" != "amd64" ]]; then
  echo "❌ Only x86_64/amd64 architecture is supported."
  exit 1
fi

# === Download URL ===
case "$PLATFORM" in
  "linux")
    URL="https://files.teamspeak-services.com/releases/server/$TS3_VER/teamspeak3-server_linux_amd64-$TS3_VER.tar.bz2"
    ;;
  "mac")
    URL="https://files.teamspeak-services.com/releases/server/$TS3_VER/teamspeak3-server_mac-$TS3_VER.tar.bz2"
    ;;
esac

# === Detect Existing Install ===
if [ -d "$TS3_DIR" ]; then
  echo "⚠️  TeamSpeak is already installed in $TS3_DIR"
  echo "Choose an option:"
  echo "  [U]pgrade (preserve config/logs)"
  echo "  [O]verwrite (delete everything)"
  echo "  [S]kip installation"
  read -p "Your choice: [U/O/S] " CHOICE
  CHOICE=$(echo "$CHOICE" | tr '[:upper:]' '[:lower:]')
  case "$CHOICE" in
    o)
      echo "❗ Overwriting existing install..."
      $SUDO rm -rf "$TS3_DIR"
      ;;
    s)
      echo "⏭️ Skipping installation."
      exit 0
      ;;
    u)
      echo "🔄 Upgrading..."
      PRESERVE_DIR=$(mktemp -d)
      cp "$TS3_DIR"/ts3server.ini "$PRESERVE_DIR" 2>/dev/null || true
      cp -r "$TS3_DIR"/logs "$PRESERVE_DIR" 2>/dev/null || true
      cp "$TS3_DIR"/ServerAdmin_Privilege_Key.txt "$PRESERVE_DIR" 2>/dev/null || true
      cp "$TS3_DIR"/Query_Login.txt "$PRESERVE_DIR" 2>/dev/null || true
      ;;
    *)
      echo "❌ Invalid option. Exiting."
      exit 1
      ;;
  esac
fi

# === Download & Extract ===
echo "📦 Installing TeamSpeak 3 Server v$TS3_VER for $OS ($ARCH)..."
mkdir -p "$TS3_DIR"
cd /tmp
curl -sSL "$URL" -o ts3.tar.bz2
tar -xjf ts3.tar.bz2
mv teamspeak3-server_*/* "$TS3_DIR"
rm -rf ts3.tar.bz2 teamspeak3-server_*/

# === Accept License ===
touch "$TS3_DIR/.ts3server_license_accepted"

# === Restore config if upgrading ===
if [ -n "$PRESERVE_DIR" ]; then
  cp "$PRESERVE_DIR"/ts3server.ini "$TS3_DIR" 2>/dev/null || true
  cp -r "$PRESERVE_DIR"/logs "$TS3_DIR" 2>/dev/null || true
  cp "$PRESERVE_DIR"/ServerAdmin_Privilege_Key.txt "$TS3_DIR" 2>/dev/null || true
  cp "$PRESERVE_DIR"/Query_Login.txt "$TS3_DIR" 2>/dev/null || true
  rm -rf "$PRESERVE_DIR"
fi

# === Permissions ===
if [ "$PLATFORM" = "linux" ]; then
  if ! id "$TS3_USER" >/dev/null 2>&1; then
    $SUDO adduser --system --group --disabled-login --disabled-password --no-create-home "$TS3_USER"
    echo "✅ Created user: $TS3_USER"
  fi
  $SUDO chown -R "$TS3_USER:$TS3_USER" "$TS3_DIR"
fi

# === Config File ===
cat > "$TS3_DIR/ts3server.ini" <<EOF
default_voice_port=9987
query_port=10011
filetransfer_port=30033
logappend=1
EOF

# === Launch Script ===
cat > "$TS3_DIR/start.sh" <<EOF
#!/bin/bash
cd "$TS3_DIR"
exec ./ts3server_minimal_runscript.sh inifile=ts3server.ini
EOF
chmod +x "$TS3_DIR/start.sh"

# === Linux systemd Setup ===
if [ "$PLATFORM" = "linux" ]; then
  echo "🛠️ Setting up systemd service..."
  $SUDO tee /etc/systemd/system/ts3server.service > /dev/null <<EOF
[Unit]
Description=TeamSpeak 3 Server
After=network.target

[Service]
Type=forking
User=$TS3_USER
WorkingDirectory=$TS3_DIR
ExecStart=$TS3_DIR/ts3server_startscript.sh start inifile=$TS3_DIR/ts3server.ini
ExecStop=$TS3_DIR/ts3server_startscript.sh stop
PIDFile=$TS3_DIR/ts3server.pid
Restart=always

[Install]
WantedBy=multi-user.target
EOF

  $SUDO systemctl daemon-reexec
  $SUDO systemctl enable ts3server
  $SUDO systemctl restart ts3server

  # === Linux Firewall Setup ===
  echo "🛡️ Configuring firewall..."
  if command -v ufw >/dev/null; then
    $SUDO ufw allow 9987/udp
    $SUDO ufw allow 10011/tcp
    $SUDO ufw allow 30033/tcp
    echo "✅ Opened ports via ufw."
  elif command -v iptables >/dev/null; then
    $SUDO iptables -A INPUT -p udp --dport 9987 -j ACCEPT
    $SUDO iptables -A INPUT -p tcp --dport 10011 -j ACCEPT
    $SUDO iptables -A INPUT -p tcp --dport 30033 -j ACCEPT
    echo "✅ Opened ports via iptables."
  else
    echo "⚠️ Firewall not configured: no ufw or iptables found."
  fi
fi

# === macOS LaunchAgent Setup ===
if [ "$PLATFORM" = "mac" ]; then
  read -p "🔁 Do you want the TeamSpeak server to autostart when you log in? [y/N]: " AUTOSTART
  AUTOSTART=$(echo "$AUTOSTART" | tr '[:upper:]' '[:lower:]')

  if [[ "$AUTOSTART" == "y" || "$AUTOSTART" == "yes" ]]; then
    PLIST_PATH="$HOME/Library/LaunchAgents/com.teamspeak.server.plist"
    mkdir -p "$(dirname "$PLIST_PATH")"

    cat > "$PLIST_PATH" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
  <dict>
    <key>Label</key>
    <string>com.teamspeak.server</string>
    <key>ProgramArguments</key>
    <array>
      <string>$TS3_DIR/start.sh</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>WorkingDirectory</key>
    <string>$TS3_DIR</string>
    <key>StandardOutPath</key>
    <string>$TS3_DIR/ts3_stdout.log</string>
    <key>StandardErrorPath</key>
    <string>$TS3_DIR/ts3_stderr.log</string>
  </dict>
</plist>
EOF

    echo "✅ Loading LaunchAgent..."
    launchctl unload "$PLIST_PATH" >/dev/null 2>&1 || true
    launchctl load "$PLIST_PATH"
    echo "✅ TeamSpeak will now autostart on login."
  else
    echo "⚠️ Autostart skipped. Use $TS3_DIR/start.sh to run manually."
  fi
fi

# === Wait & Fetch Credentials ===
echo "⏳ Waiting for server log to generate credentials..."
sleep 5
LOGFILE=$(ls -t "$TS3_DIR"/logs/*_1.log 2>/dev/null | head -n 1)
TOKEN=$(grep -o 'token=.*' "$LOGFILE" | cut -d= -f2 || true)
QUERY_USER=$(grep -o 'loginname= *"[^"]*"' "$LOGFILE" | head -1 | cut -d'"' -f2 || true)
QUERY_PASS=$(grep -o 'password= *"[^"]*"' "$LOGFILE" | head -1 | cut -d'"' -f2 || true)

echo "$TOKEN" > "$TS3_DIR/ServerAdmin_Privilege_Key.txt"
echo "$QUERY_USER:$QUERY_PASS" > "$TS3_DIR/Query_Login.txt"

# === External IP ===
EXT_IP=$(curl -s https://ipinfo.io/ip || echo "Unknown")

# === Output Info ===
echo ""
echo "🎉 Installation Complete!"

echo "🔐 ServerAdmin Privilege Key: $TOKEN"
echo "📄 Saved to: $TS3_DIR/ServerAdmin_Privilege_Key.txt"

echo "🛠️  ServerQuery Login:"
echo "   Username: $QUERY_USER"
echo "   Password: $QUERY_PASS"
echo "📄 Saved to: $TS3_DIR/Query_Login.txt"

echo "🌍 External IP Address: $EXT_IP"
echo ""

exit 0
