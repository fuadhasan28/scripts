#varables
nopVersion="4.60.0"

# utilite functions

change_permission_and_owner(){
    local dirs="$1"
    for dir in "${dirs[@]}"; do
		if [ ! -d "$dir" ]; then
			echo creating the dir "$dir"
			sudo -S mkdir -m 7777 "$dir"
		fi
        echo working with "$dir"
        sudo -S chmod 777 "$dir" && sudo -S chown www-data:www-data "$dir"
        for file in "$dir/"*; do
            echo modifing the file: "$file"
            sudo -S chmod 777 "$file" && sudo -S chown www-data:www-data "$file"
        done
    done
}

check_and_create_directory() {
    local dir="$1"
    if [ ! -d "$dir" ]; then
        echo creating the dir "$dir"
        sudo -S mkdir -m 7777 "$dir"
    else 
        sudo -S chmod 7777 "$dir"
    fi
	#sudo -S chown www-data:www-data "$dir"
}

check_and_create_directory_and_change_owner() {
    local dir="$1"
    if [ ! -d "$dir" ]; then
        echo creating the dir "$dir"
        sudo -S mkdir -m 7777 "$dir"
    else 
        sudo -S chmod 7777 "$dir"
    fi
	sudo -S chown www-data:www-data "$dir"
}


#nop hosting dir
nopHostingDir="/var/www/eCom/nuPodTest"
webRootPath="/var/www/eCom/nuPodTest"

check_and_create_directory "/var/www"
check_and_create_directory "/var/www/eCom"

#install asp.net

# Check if dotnet-runtime-7.0 is installed
if ! dpkg -s dotnet-runtime-7.0 &>/dev/null; then
    # If not installed, install dotnet-runtime-7.0
    echo "dotnet-runtime-7.0 is not installed. Installing..."
	
	wget https://packages.microsoft.com/config/ubuntu/$(lsb_release -rs)/packages-microsoft-prod.deb -O packages-microsoft-prod.deb
	sudo dpkg -i packages-microsoft-prod.deb
	sudo apt update -y
	sudo apt install apt-transport-https -y
	sudo apt-get install -y dotnet-runtime-7.0
else
    echo "dotnet-runtime-7.0 is already installed."
fi

dotnet --list-runtimes

#download and install nopCommerce

#sudo mkdir /var/www/shop.example.com
sudo mkdir $nopHostingDir
sudo cd $nopHostingDir
zip_file="nopCommerce_${nopVersion}_NoSource_linux_x64.zip"
#https://github.com/nopSolutions/nopCommerce/releases/download/release-4.60.6/nopCommerce_4.60.6_NoSource_linux_x64.zip
#https://github.com/nopSolutions/nopCommerce/releases/download/release-${nopVersion}/nopCommerce_${nopVersion}_NoSource_linux_x64.zip
sudo wget https://github.com/nopSolutions/nopCommerce/releases/download/release-${nopVersion}/nopCommerce_${nopVersion}_NoSource_linux_x64.zip
sudo -S unzip -o nopCommerce_${nopVersion}_NoSource_linux_x64.zip -d "$nopHostingDir/"
#sudo unzip nopCommerce_4.60.6_NoSource_linux_x64.zip
rm nopCommerce_${nopVersion}_NoSource_linux_x64.zip

sudo -S chown www-data:www-data $nopHostingDir/*
sudo -S chown www-data:www-data "$nopHostingDir"
sudo -S chown www-data:www-data "$nopHostingDir/"

directories=("/var/www" "/var/www/eCom" "$webRootPath" "$webRootPath/App_Data" "$webRootPath/wwwroot" "$webRootPath/wwwroot/images" "$webRootPath/wwwroot/images/thumbs" "$webRootPath/wwwroot/js" "$webRootPath/wwwroot/uploads")

for dir in "${directories[@]}"; do
    check_and_create_directory_and_change_owner "$dir"
done

wwwRootPath="$nopHostingDir/wwwroot"

permission_paths=("$nopHostingDir" "$wwwRootPath" "$wwwRootPath/css"  "$wwwRootPath/images" "$wwwRootPath/lib" "$wwwRootPath/my-bucket" "$wwwRootPath/images/thumbs" "$wwwRootPath/js" "$wwwRootPath/uploads" "/var/www/eCom/nuPodTest/App_Data/")
change_permission_and_owner "${permission_paths[@]}" 

rm -rf /var/www/eCom/nuPodTest/App_Data/appsettings.json

sudo chmod -R 755 "$nopHostingDir" && sudo chown -R www-data:www-data "$nopHostingDir"

# writing service

#!/bin/bash
cd /etc/systemd/system/
serviceName="ecom_nupod_test.service"

cat <<EOF > "$serviceName"
[Unit]
Description=NopCommerce eCommerce application

[Service]
WorkingDirectory=$nopHostingDir
ExecStart=/usr/bin/dotnet "$nopHostingDir/Nop.Web.dll" --urls=http://0.0.0.0:7089
Restart=always

# Auto restart nopCommerce in 10 seconds if .NET crashes

RestartSec=10
KillSignal=SIGINT
SyslogIdentifier=nopcommerce
User=www-data
Environment=ASPNETCORE_ENVIRONMENT=Production
Environment=DOTNET_PRINT_TELEMETRY_MESSAGE=false

[Install]
WantedBy=multi-user.target
EOF

echo "$serviceName file created successfully."

sudo systemctl daemon-reload
sudo systemctl enable $serviceName
sudo systemctl start $serviceName
sudo systemctl status $serviceName