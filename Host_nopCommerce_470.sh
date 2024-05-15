if ! command -v unzip &> /dev/null; then
    # If not installed, try to install it
    echo "Unzip is not installed. Attempting to install..."
    
    # Check if apt package manager is available
    if command -v apt &> /dev/null; then
        sudo apt update -y
        sudo apt install unzip -y
    # Check if yum package manager is available
    elif command -v yum &> /dev/null; then
        sudo yum install unzip
    else
        echo "Package manager not found. Please install unzip manually."
        exit 1
    fi

    # Verify installation
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

webRootPath="/var/www"
etcPath="/etc/systemd/system"

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

check_and_create_directory "$webRootPath"



# ************************************************************ nopCommerce versions ************************************************************
# nopCommerce versions
dirNServiceName=""
nopVersion="4.70.0"
nopCommerce_versions=(
    "4.70.0"
)

print_array() {
    echo -e "Available nopCommerce versions:\e[33m"
    for i in "${!nopCommerce_versions[@]}"; do
        echo "$((i+1)) : nopCommerce - ${nopCommerce_versions[i]}"
    done
	
    echo -e "\e[0mPlease enter a number between 1 and ${#nopCommerce_versions[@]}."
}

# Function to validate input index
validate_index() {
    local index="$1"
    if [[ "$index" =~ ^[0-9]+$ && "$index" -ge 1 && "$index" -le ${#nopCommerce_versions[@]} ]]; then
        return 0
    else
        return 1
    fi
}

print_array

while true; do
    read -p "Enter an index: " index
    if validate_index "$index"; then
        valid_index=$((index-1))
        echo "Element at index $index is: ${nopCommerce_versions[valid_index]}"
        nopVersion="${nopCommerce_versions[valid_index]}"
        break
    else
        echo "Invalid value. Please enter a valid number between 1 and ${#nopCommerce_versions[@]}."
    fi
done

echo "Installing nopCommerce versions: $nopVersion"



# ************************************************************ hosting folder and service name ************************************************************
# Function to validate input
validate_input() {
    local input="$1"
    if [[ ${#input} -le 2 || $input =~ [^a-zA-Z0-9_.] ]]; then
        return 1
    else
        return 0
    fi
}

# Function to check if a directory exists
check_directory() {
	checkDirName="nop_${nopVersion}_${1}"
    if [ -d "$webRootPath/$checkDirName" ]; then
        echo "Directory '$webRootPath/$checkDirName' already exists."
        return 0
    else
        echo "Directory '$webRootPath/$checkDirName' does not exist."
        return 1
    fi
}

# Function to check if a service file exists
check_service() {
	checkServiceName="nop_${nopVersion}_${1}.service"
    if [ -f "$etcPath/$checkServiceName" ]; then
        echo "Service file '$etcPath/$checkServiceName' already exists."
        return 0
    else
        echo "Service file '$etcPath/$checkServiceName' does not exist."
        return 1
    fi
}

# Main loop to take input until valid
while true; do
    read -p "Enter a name for hosting dir and service (length > 2, no special characters or spaces): " input
    if ! validate_input "$input"; then
        echo "Invalid input. Please try again."
    else
        # Check if directory or service file exists
        check_directory "$input" && continue
        check_service "$input" && continue
        break
    fi
done

dirNServiceName="$input"
nopHostingDir="$webRootPath/nop_${nopVersion}_${dirNServiceName}"
echo -e "Hosting path: \e[93m'$nopHostingDir'\e[0m"

serviceName="nop_${nopVersion}_${dirNServiceName}.service"
echo -e "ServiceName: \e[93m$serviceName\e[0m"


# ************************************************************ port for nop ************************************************************
# Function to check if a port is available
is_port_available() {
    local port=$1
    if ! nc -z localhost "$port"; then
        return 0
    else
        return 1
    fi
}

# Reserved ports to exclude
reserved_ports=(80 22)

# Function to generate a random port
generate_random_port() {
    local available_ports=()
    for ((port=5001; port<=9000; port++)); do
        if [[ ! " ${reserved_ports[@]} " =~ " $port " ]] && is_port_available "$port"; then
            available_ports+=("$port")
        fi
    done
    # Select a random port from available ports
    local random_index=$((RANDOM % ${#available_ports[@]}))
    echo "${available_ports[random_index]}"
}

# Prompt user to accept, deny, choose a port, or exit
prompt_user() {
    local port="$1"
    while true; do
        echo -e "A random port \e[93m$port\e[0m is available. Do you want to accept it? \e[91m Type(y/n) or 'exit' to exit or type 'c' \e[0mto input a port of your choice(Anyother input to continue with \e[93m$port\e[0m port): " 
        read -p "Your choice:" choice
        case "$choice" in
            n|N) return 1 ;;
            exit) echo "\e[32mExiting...\e[0m"; exit ;;
            c) read -p "Enter a port of your choice: " chosen_port
                    if [[ "$chosen_port" =~ ^[0-9]+$ ]]; then
                        if ! [[ " ${reserved_ports[@]} " =~ " $chosen_port " ]] && is_port_available "$chosen_port"; then
                            echo -e "Chosen port \e[93m$chosen_port\e[0m is available."
                            return 0
                        else
                            echo -e "Port \e[93m$chosen_port\e[0m is not available or is reserved. Please choose another port."
                        fi
                    else
                        echo -e "\e[31mInvalid port number. Please enter a valid port number.\e[0m "
                    fi ;;
            y|Y|*) return 0 ;;
        esac
    done
}

# Main script
echo -e "\e[32mSearching for available port...\e[0m"
while true; do
    port=$(generate_random_port)
    if [[ -z "$port" ]]; then
        echo -e "\e[31mNo available port found.\e[0m"
        exit 1
    fi
    if prompt_user "$port"; then
        if [[ "$choice" == "c" ]]; then
            echo -e "Chosen port: \e[32m$chosen_port\e[0m"
			port=$chosen_port
        else
            echo -e "\e[32mAccepted port: $port\e[0m"
        fi
        break
    else
        echo -e "Port \e[31m$port\e[0m denied. Searching for another available port..."
    fi
done

# ************************************************************ start hosting nop ************************************************************

#nop hosting dir
sudo ufw allow $port
check_and_create_directory $nopHostingDir

#install asp.net

# Check if dotnet-runtime-8.0 is installed
if ! dpkg -s dotnet-runtime-8.0 &>/dev/null; then
    # If not installed, install dotnet-runtime-8.0
    echo -e "\e[93mdotnet-runtime-8.0 is not installed. Installing...\e[0m"
	wget https://packages.microsoft.com/config/ubuntu/$(lsb_release -rs)/packages-microsoft-prod.deb -O packages-microsoft-prod.deb
	sudo dpkg -i packages-microsoft-prod.deb
	sudo apt update -y
	sudo apt install apt-transport-https -y
	sudo apt-get install -y dotnet-runtime-8.0
	sudo apt install -y aspnetcore-runtime-8.0
else
    echo -e "\e[93mdotnet-runtime-8.0 is already installed.\e[0m"
fi

dotnet --list-runtimes

# ------------------------------------- download and install nopCommerce ------------------------------------- 

#sudo mkdir $nopHostingDir
echo "Hosting dir : $nopHostingDir"
cd "$nopHostingDir"

zip_file="nopCommerce_${nopVersion}_NoSource_linux_x64.zip"
#https://github.com/nopSolutions/nopCommerce/releases/download/release-4.60.6/nopCommerce_4.60.6_NoSource_linux_x64.zip
#https://github.com/nopSolutions/nopCommerce/releases/download/release-${nopVersion}/nopCommerce_${nopVersion}_NoSource_linux_x64.zip
echo wget https://github.com/nopSolutions/nopCommerce/releases/download/release-${nopVersion}/nopCommerce_${nopVersion}_NoSource_linux_x64.zip
sudo wget https://github.com/nopSolutions/nopCommerce/releases/download/release-${nopVersion}/nopCommerce_${nopVersion}_NoSource_linux_x64.zip
sudo -S unzip -o nopCommerce_${nopVersion}_NoSource_linux_x64.zip -d "$nopHostingDir/"
#sudo unzip nopCommerce_4.60.6_NoSource_linux_x64.zip
sudo rm -rf nopCommerce_${nopVersion}_NoSource_linux_x64.zip

sudo -S chown www-data:www-data $nopHostingDir/*
sudo -S chown www-data:www-data "$nopHostingDir"
sudo -S chown www-data:www-data "$nopHostingDir/"

directories=("$nopHostingDir" "$nopHostingDir/App_Data" "$nopHostingDir/wwwroot" "$nopHostingDir/wwwroot/images" "$nopHostingDir/wwwroot/images/thumbs" "$nopHostingDir/wwwroot/js" "$nopHostingDir/wwwroot/uploads")

# for dir in "${directories[@]}"; do
    # check_and_create_directory_and_change_owner "$dir"
# done

wwwRootPath="$nopHostingDir/wwwroot"

permission_paths=("$nopHostingDir" "$wwwRootPath" "$wwwRootPath/css"  "$wwwRootPath/images" "$wwwRootPath/lib" "$wwwRootPath/my-bucket" "$wwwRootPath/images/thumbs" "$wwwRootPath/js" "$wwwRootPath/uploads" "$nopHostingDir/App_Data/")
#change_permission_and_owner "${permission_paths[@]}" 

sudo rm -rf "$nopHostingDir/App_Data/appsettings.json"

sudo chmod -R 755 "$nopHostingDir" && sudo chown -R www-data:www-data "$nopHostingDir"

#ls -l
echo ls -l "$nopHostingDir/App_Data"
ls -l "$nopHostingDir/App_Data"

echo ls -l "$wwwRootPath/*"
ls -l "$wwwRootPath/*"

# writing service

#!/bin/bash
cd "$etcPath"
#serviceName="nop_$nopVersion_$dirNServiceName.service"

sudo cat <<EOF > "$serviceName"
[Unit]
Description=NopCommerce eCommerce application

[Service]
WorkingDirectory=$nopHostingDir
ExecStart=/usr/bin/dotnet "$nopHostingDir/Nop.Web.dll" --urls=http://0.0.0.0:$port
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

echo -e "\e[93m$serviceName\e[0m file created successfully."

sudo cat "$serviceName"


sudo systemctl daemon-reload
sudo systemctl enable $serviceName
sudo systemctl start $serviceName

echo -e "\e[31mnopCommerce is hosted on the port : \"$port\". If you are using any cloud service with a public IP, please allow the port: \"$port\" from their dashboard if you want to access with the IP\e[0m"


 