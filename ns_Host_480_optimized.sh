#!/bin/bash

# Check and install unzip if not available
if ! command -v unzip &>/dev/null; then
    echo "Unzip not found. Installing..."
    if command -v apt &>/dev/null; then
        sudo apt update -y && sudo apt install unzip -y
    elif command -v yum &>/dev/null; then
        sudo yum install unzip -y
    else
        echo "No supported package manager found. Install unzip manually."; exit 1
    fi
    command -v unzip &>/dev/null || { echo "Unzip installation failed."; exit 1; }
fi

echo "Unzip is installed."

# ------------------ VARIABLES ------------------
wwwRootPath="/var/www"
webRootPath="$wwwRootPath/NopSites"
etcPath="/etc/systemd/system"
baseNopVersion="480"
dotnetVersion="9.0"
nopVersion="4.80.0"

siteTypeOptions=("Demo" "Test" "AppSite" "Theme" "Client" "Other")
selectedSiteType="Test"

# ------------------ FUNCTIONS ------------------
create_dir() {
    local dir="$1"
    sudo mkdir -p "$dir"
    sudo chmod 777 "$dir"
    sudo chown -R www-data:www-data "$dir"
}

prompt_selection() {
    local prompt="$1"
    local -n options=$2
    echo -e "$prompt\e[33m"
    for i in "${!options[@]}"; do echo "$((i+1)) : ${options[i]}"; done
    echo -e "\e[0m"

    while true; do
        read -p "Enter a number [default: 2]: " choice
        [[ -z "$choice" ]] && echo "Using default: ${options[1]}" && return 1
        [[ "$choice" =~ ^[0-9]+$ && "$choice" -ge 1 && "$choice" -le ${#options[@]} ]] && return "$((choice - 1))"
        echo "Invalid choice."
    done
}

is_port_available() {
    ! nc -z localhost "$1" 2>/dev/null
}

generate_port() {
    for ((p=5001; p<=9000; p++)); do
        [[ "$p" =~ ^(22|80)$ ]] && continue
        is_port_available "$p" && echo "$p" && return
    done
}

prompt_port() {
    local tried_ports=()
    while true; do
        local port
        port=$(generate_port)

        # Ensure we suggest a new port each time
        while [[ " ${tried_ports[*]} " =~ " $port " ]]; do
            port=$(generate_port)
        done
        tried_ports+=("$port")

        echo -e "\e[33mSuggested available port:\e[93m $port\e[0m"
        read -p "Use this port? [y=Yes / n=No / c=Custom]: " choice

        case "$choice" in
            [nN]) continue ;;
            [cC])
                read -p "Enter a port: " custom
                if [[ "$custom" =~ ^[0-9]+$ && "$custom" -ge 1024 && "$custom" -le 65535 && "$custom" != "80" && "$custom" != "22" ]] && is_port_available "$custom"; then
                    echo "$custom"
                    return
                else
                    echo -e "\e[31mInvalid or unavailable port. Try again.\e[0m"
                fi ;;
            *|[yY])
                echo "$port"
                return ;;
        esac
    done
}


# ------------------ MAIN ------------------

create_dir "$wwwRootPath"
create_dir "$webRootPath"

# --- SITE TYPE SELECTION ---
prompt_selection "Available site types:" siteTypeOptions
[[ $? -ge 0 ]] && selectedSiteType="${siteTypeOptions[$?]}"
[[ "$selectedSiteType" == "Other" ]] && read -p "Enter custom site type: " custom && [[ -n "$custom" ]] && selectedSiteType="$custom"

echo "Selected site type: $selectedSiteType"

hostingPath="$webRootPath/$selectedSiteType/$baseNopVersion"
create_dir "$hostingPath"

# --- DIR/SERVICE NAME ---
while true; do
    read -p "Enter hosting/service name (min 3 chars, alphanum/underscore only): " input
    [[ "$input" =~ ^[a-zA-Z0-9_]{3,}$ ]] || { echo "Invalid input."; continue; }

    dirNServiceName="$input"
    nopHostingDir="$hostingPath/${selectedSiteType}_$dirNServiceName"
    serviceName="nop_${selectedSiteType}_${dirNServiceName}_${baseNopVersion}.service"

    [[ -d "$nopHostingDir" ]] && echo "Directory exists." && continue
    [[ -f "$etcPath/$serviceName" ]] && echo "Service file exists." && continue
    break
done

# --- PORT SELECTION ---
port=$(prompt_port)
[[ -z "$port" ]] && echo "No port selected. Exiting." && exit 1
echo "Using port: $port"
sudo ufw allow "$port"

# --- .NET RUNTIME INSTALL ---
if ! dotnet --list-runtimes | grep -q "$dotnetVersion"; then
    echo "Installing .NET $dotnetVersion..."
    wget https://packages.microsoft.com/config/ubuntu/$(lsb_release -rs)/packages-microsoft-prod.deb -O packages-microsoft-prod.deb
    sudo dpkg -i packages-microsoft-prod.deb
    sudo apt update -y
    sudo apt install -y apt-transport-https dotnet-runtime-"$dotnetVersion" aspnetcore-runtime-"$dotnetVersion"
    rm -f packages-microsoft-prod.deb
fi

# --- DOWNLOAD NOPCOMMERCE ---
create_dir "$nopHostingDir"
cd "$nopHostingDir"
zip="nopCommerce_${nopVersion}_NoSource_linux_x64.zip"
url="https://github.com/nopSolutions/nopCommerce/releases/download/release-${nopVersion}/${zip}"

sudo wget "$url"
sudo unzip -o "$zip" -d .
sudo rm -f "$zip"

sudo chown -R www-data:www-data "$nopHostingDir"
sudo chmod -R 755 "$nopHostingDir"
sudo rm -f "$nopHostingDir/App_Data/appsettings.json"

# --- CREATE SYSTEMD SERVICE ---
sudo tee "$etcPath/$serviceName" >/dev/null <<EOF
[Unit]
Description=nopCommerce $nopVersion - $selectedSiteType - $dirNServiceName
[Service]
WorkingDirectory=$nopHostingDir
ExecStart=/usr/bin/dotnet $nopHostingDir/Nop.Web.dll --urls=http://0.0.0.0:$port
Restart=always
RestartSec=10
KillSignal=SIGINT
SyslogIdentifier=nopcommerce
User=www-data
Environment=ASPNETCORE_ENVIRONMENT=Production
Environment=DOTNET_PRINT_TELEMETRY_MESSAGE=false
[Install]
WantedBy=multi-user.target
EOF

# --- ENABLE & START SERVICE ---
sudo systemctl daemon-reload
sudo systemctl enable "$serviceName"
sudo systemctl start "$serviceName"

echo -e "\e[92mnopCommerce hosted on port $port. Open firewall and cloud security rules if needed.\e[0m"
