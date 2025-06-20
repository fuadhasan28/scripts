#!/bin/bash

echo "🔧 Setting up HTTPS for your nopCommerce app..."

# Get systemd service name
read -rp "🛠️ Enter the systemd service name (e.g., Nop_470_DrinkSpot_Test  or with .service): " SERVICE_NAME
SERVICE_NAME=${SERVICE_NAME%.service}  # Remove .service if present

SERVICE_PATH="/etc/systemd/system/${SERVICE_NAME}.service"

# Validate service file
if [[ ! -f "$SERVICE_PATH" ]]; then
  echo "❌ Service file not found: $SERVICE_PATH"
  exit 1
fi

# Show contents of service file
echo ""
echo "📄 Contents of $SERVICE_PATH:"
echo "----------------------------------------"
cat "$SERVICE_PATH"
echo "----------------------------------------"
echo ""

# Extract APP_FOLDER from WorkingDirectory
APP_FOLDER=$(grep -oP '^WorkingDirectory=\K.*' "$SERVICE_PATH" | head -1)

if [[ -z "$APP_FOLDER" || ! -d "$APP_FOLDER" ]]; then
  echo "❌ Could not extract valid WorkingDirectory from service file."
  exit 1
fi

echo -e "\e[0m📁 Detected APP_FOLDER from service file: \e[93m$APP_FOLDER\e[0m"

APP_NAME=$(basename "$APP_FOLDER")
DOTNET_DLL_PATH="${APP_FOLDER}/Nop.Web.dll"

# Validate DLL
if [[ ! -f "$DOTNET_DLL_PATH" ]]; then
  echo "❌ DLL not found: $DOTNET_DLL_PATH"
  exit 1
fi

# Extract port
EXTRACTED_PORT=$(grep -oP -- '--urls=http[s]?://[0-9.:]*:\K[0-9]+' "$SERVICE_PATH" | head -1)

if [[ -z "$EXTRACTED_PORT" ]]; then
  echo "⚠️  Could not extract port automatically."
  read -rp "🔢 Please enter the port manually: " PORT
else
  echo -e "\e[0m📦 Detected port is \e[93m$EXTRACTED_PORT\e[0m."
  read -rp "Is this correct? (Y/n): " PORT_CONFIRM
  if [[ "$PORT_CONFIRM" =~ ^[Nn]$ ]]; then
    read -rp "🔢 Please enter the correct port: " PORT
  else
    PORT="$EXTRACTED_PORT"
  fi
fi

# Validate port
if ! [[ "$PORT" =~ ^[0-9]+$ ]]; then
  echo "❌ Invalid port number: $PORT"
  exit 1
fi

# Certificate paths
CERT_DIR="/var/www/ssl"
CERT_PFX="${CERT_DIR}/${APP_NAME}.pfx"
CERT_PASS=$(openssl rand -base64 16)

# Create cert dir
sudo mkdir -p "$CERT_DIR"
cd "$CERT_DIR" || exit 1

# Generate cert
echo "🔐 Generating self-signed certificate..."
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout "${APP_NAME}.key" \
  -out "${APP_NAME}.crt" \
  -subj "/CN=localhost"

openssl pkcs12 -export \
  -out "$CERT_PFX" \
  -inkey "${APP_NAME}.key" \
  -in "${APP_NAME}.crt" \
  -passout pass:"$CERT_PASS"

# Set ownership and permissions
chown www-data:www-data "$CERT_PFX"
chmod 600 "$CERT_PFX"

# Environment override for cert config
OVERRIDE_DIR="/etc/systemd/system/${SERVICE_NAME}.service.d"
sudo mkdir -p "$OVERRIDE_DIR"
sudo tee "${OVERRIDE_DIR}/override.conf" > /dev/null <<EOF
[Service]
Environment="ASPNETCORE_Kestrel__Certificates__Default__Path=${CERT_PFX}"
Environment="ASPNETCORE_Kestrel__Certificates__Default__Password=${CERT_PASS}"
EOF

# Replace --urls=http://... with https
echo "🛠️ Updating service file to use HTTPS..."
sudo sed -i "s|--urls=http://[^ ]*|--urls=https://0.0.0.0:${PORT}|g" "$SERVICE_PATH"

# Ask about NGINX
read -rp "🌐 Are you using NGINX as a reverse proxy? (y/n): " USE_NGINX

if [[ "$USE_NGINX" =~ ^[Yy]$ ]]; then
  read -rp "📝 Enter the full path to the NGINX config file: " NGINX_CONF

  if [[ ! -f "$NGINX_CONF" ]]; then
    echo "❌ NGINX config file not found: $NGINX_CONF"
  else
    echo "✏️ Updating NGINX proxy_pass for port $PORT to use HTTPS..."
    sudo sed -i "s|proxy_pass http://127.0.0.1:${PORT};|proxy_pass https://127.0.0.1:${PORT};|g" "$NGINX_CONF"
    sudo nginx -t && sudo systemctl reload nginx
  fi
fi

# Reload and restart
echo "🔄 Restarting systemd service..."
sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl restart "$SERVICE_NAME"

# Summary
echo ""
echo "✅ $APP_NAME is now running with HTTPS at https://127.0.0.1:${PORT}"
echo "🔐 Certificate Path: $CERT_PFX"
echo "🔑 Certificate Password: $CERT_PASS"
[[ "$USE_NGINX" =~ ^[Yy]$ ]] && echo "🌐 NGINX config updated to use HTTPS for proxy_pass"
