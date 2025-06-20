#!/bin/bash

if ! command -v unzip &> /dev/null; then
    echo "Unzip is not installed. Attempting to install..."
    if command -v apt &> /dev/null; then
        sudo apt update -y
        sudo apt install unzip -y
    elif command -v yum &> /dev/null; then
        sudo yum install unzip
    else
        echo "Package manager not found. Please install unzip manually."
        exit 1
    fi
    if ! command -v unzip &> /dev/null; then
        echo "Failed to install unzip. Please install it manually."
        exit 1
    else
        echo "Unzip has been successfully installed."
    fi
else
    echo "Unzip is already installed."
fi

# region initial

wwwRootPath="/var/www"
webRootPath="$wwwRootPath/NopSites"
etcPath="/etc/systemd/system"
baseNopVersion="450"

change_permission_and_owner(){
    local dirs="$1"
    for dir in "${dirs[@]}"; do
        if [ ! -d "$dir" ]; then
            echo creating the dir "$dir"
            sudo mkdir -m 7777 "$dir"
        fi
        echo working with "$dir"
        sudo chmod 777 "$dir" && sudo chown www-data:www-data "$dir"
        for file in "$dir/"*; do
            echo modifing the file: "$file"
            sudo chmod 777 "$file" && sudo chown www-data:www-data "$file"
        done
    done
}

check_and_create_directory() {
    local dir="$1"
    if [ ! -d "$dir" ]; then
        echo creating the dir "$dir"
        sudo mkdir -m 7777 "$dir"
    else
        sudo chmod 7777 "$dir"
    fi
}

check_and_create_directory "$wwwRootPath"
check_and_create_directory "$webRootPath"

siteTypeOptions=("Demo" "Test" "AppSite" "Theme" "Client")
selectedSiteType="Test"

print_site_types() {
    echo -e "Available site types:\e[33m"
    for i in "${!siteTypeOptions[@]}"; do
        echo "$((i+1)) : ${siteTypeOptions[i]}"
    done
    echo -e "\e[0mPlease enter a number between 1 and ${#siteTypeOptions[@]}, or press Enter to use the default [Test]."
}

print_site_types

while true; do
    read -p "Enter an index for site type (default is Test): " siteTypeIndex
    if [[ -z "$siteTypeIndex" ]]; then
        echo "No input provided. Using default site type: $selectedSiteType"
        break
    elif [[ "$siteTypeIndex" =~ ^[0-9]+$ && "$siteTypeIndex" -ge 1 && "$siteTypeIndex" -le ${#siteTypeOptions[@]} ]]; then
        selectedSiteType="${siteTypeOptions[siteTypeIndex-1]}"
        echo "Selected site type: ${selectedSiteType}"
        break
    else
        echo "Invalid value. Please enter a valid number between 1 and ${#siteTypeOptions[@]}, or press Enter to use the default."
    fi
done

check_and_create_directory "$webRootPath/$selectedSiteType"
check_and_create_directory "$webRootPath/$selectedSiteType/450"
hostingPath="$webRootPath/$selectedSiteType/${baseNopVersion}"

nopVersion="4.50.0"
nopCommerce_versions=("4.50.4" "4.50.3" "4.50.2" "4.50.1" "4.50.0")

print_array() {
    echo -e "Available nopCommerce versions:\e[33m"
    for i in "${!nopCommerce_versions[@]}"; do
        echo "$((i+1)) : nopCommerce - ${nopCommerce_versions[i]}"
    done
}

print_array

while true; do
    read -p "Enter an index: " index
    if [[ "$index" =~ ^[0-9]+$ && "$index" -ge 1 && "$index" -le ${#nopCommerce_versions[@]} ]]; then
        nopVersion="${nopCommerce_versions[index-1]}"
        break
    else
        echo "Invalid value. Please enter a valid number between 1 and ${#nopCommerce_versions[@]}."
    fi
done

# Install .NET 6 runtime if not already installed
if ! dpkg -s dotnet-runtime-6.0 &>/dev/null; then
    echo -e "\e[93mInstalling dotnet-runtime-6.0...\e[0m"
    wget https://packages.microsoft.com/config/ubuntu/$(lsb_release -rs)/packages-microsoft-prod.deb -O packages-microsoft-prod.deb
    sudo dpkg -i packages-microsoft-prod.deb
    sudo apt update -y
    sudo apt install -y dotnet-runtime-6.0
else
    echo -e "\e[93m.NET 6 runtime is already installed.\e[0m"
fi

dotnet --list-runtimes

cd "$hostingPath"
zip_file="nopCommerce_${nopVersion}_NoSource_linux_x64.zip"
wget https://github.com/nopSolutions/nopCommerce/releases/download/release-${nopVersion}/nopCommerce_${nopVersion}_NoSource_linux_x64.zip
sudo unzip -o nopCommerce_${nopVersion}_NoSource_linux_x64.zip -d "$hostingPath/"
sudo rm -rf nopCommerce_${nopVersion}_NoSource_linux_x64.zip

directories=("$hostingPath" "$hostingPath/App_Data" "$hostingPath/wwwroot" "$hostingPath/wwwroot/images")
change_permission_and_owner "${directories[@]}"

port=5001

serviceName="nop_${selectedSiteType}_${nopVersion}.service"

sudo cat <<EOF > "$etcPath/$serviceName"
[Unit]
Description=NopCommerce $nopVersion application type of $selectedSiteType

[Service]
WorkingDirectory=$hostingPath
ExecStart=/usr/bin/dotnet "$hostingPath/Nop.Web.dll" --urls=http://0.0.0.0:$port
Restart=always
RestartSec=10
SyslogIdentifier=nopcommerce
User=www-data
Environment=ASPNETCORE_ENVIRONMENT=Production
Environment=DOTNET_PRINT_TELEMETRY_MESSAGE=false

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable $serviceName
sudo systemctl start $serviceName

echo -e "\e[31mnopCommerce is hosted on port $port. Configure firewall or cloud settings as needed.\e[0m"
