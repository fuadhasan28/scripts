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

wwwRootPath="/var/www"
webRootPath="$wwwRootPath/NopSites"
etcPath="/etc/systemd/system"
baseNopVersion="490"
dotnetVersion="9.0"


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

check_and_create_directory "$wwwRootPath"
check_and_create_directory "$webRootPath"
# ************************************************************ site types ************************************************************
# Define site types array
siteTypeOptions=(
    "Demo"
    "Test"
    "AppSite"
    "Theme"
    "Client"
    "Other"
)

# Initialize selectedSiteType with default value "Test"
selectedSiteType="Test"

# Function to print available site types
print_site_types() {
    echo -e "Available site types:\e[33m"
    for i in "${!siteTypeOptions[@]}"; do
        echo "$((i+1)) : ${siteTypeOptions[i]}"
    done
    echo -e "\e[0mPlease enter a number between 1 and ${#siteTypeOptions[@]}, or press Enter to use the default [Test]."
}

# Function to validate site type index
validate_site_type_index() {
    local index="$1"
    if [[ "$index" =~ ^[0-9]+$ && "$index" -ge 1 && "$index" -le ${#siteTypeOptions[@]} ]]; then
        return 0
    else
        return 1
    fi
}

# Display site types and get user input
print_site_types

while true; do
    read -e -p "Enter an index for site type (default is Test): " siteTypeIndex
    if [[ -z "$siteTypeIndex" ]]; then
        echo "No input provided. Using default site type: $selectedSiteType"
        break
    elif validate_site_type_index "$siteTypeIndex"; then
        valid_siteType_index=$((siteTypeIndex-1))
        selectedSiteType="${siteTypeOptions[valid_siteType_index]}"
        
        # If "Other" is selected, ask for custom input
        if [[ "$selectedSiteType" == "Other" ]]; then
            read -e -p "Please enter a custom site type: " customSiteType
            if [[ -n "$customSiteType" ]]; then
                selectedSiteType="$customSiteType"
                echo "Custom site type selected: $selectedSiteType"
            else
                echo "No input provided. Defaulting to 'Other'."
                selectedSiteType="Other"
            fi
        else
            echo "Selected site type: ${selectedSiteType}"
        fi
        break
    else
        echo "Invalid value. Please enter a valid number between 1 and ${#siteTypeOptions[@]}, or press Enter to use the default."
    fi
done

echo "Proceeding with site type: $selectedSiteType"

check_and_create_directory "$webRootPath/$selectedSiteType"
check_and_create_directory "$webRootPath/$selectedSiteType/${baseNopVersion}"
hostingPath="$webRootPath/$selectedSiteType/${baseNopVersion}"

# ************************************************************ nopCommerce versions ************************************************************
# nopCommerce versions
dirNServiceName=""
nopVersion="4.90.0"
nopCommerce_versions=(
    "4.90.4"
    "4.90.3"
    "4.90.2"
    "4.90.1"
    "4.90.0"
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
    read -e -p "Enter an index: " index
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
	checkDirName="${1}"
    if [ -d "$hostingPath/${selectedSiteType}_$checkDirName" ]; then
        echo "Directory '$hostingPath/$checkDirName' already exists."
        return 0
    else
        echo "Directory '$hostingPath/$checkDirName' does not exist."
        return 1
    fi
}

# Function to check if a service file exists
check_service() {
	checkServiceName="nop_${selectedSiteType}_${baseNopVersion}_${1}.service"
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
    read -e -p "Enter a name for hosting dir and service (length > 2, no special characters or spaces): " input
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
nopHostingDir="$hostingPath/${selectedSiteType}_${dirNServiceName}"
echo -e "Hosting path: \e[93m'$nopHostingDir'\e[0m"

serviceName="nop_${selectedSiteType}_${dirNServiceName}_${baseNopVersion}.service"
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

# Prompt user for port choice
while true; do
    echo -e "\nHow do you want to configure the port for nopCommerce?"
    echo "1) Input a port manually"
    echo "2) Proceed with a random available port"
    echo "3) Exit"
    read -e -p "Enter your choice (1, 2, or 3): " port_choice
    
    case "$port_choice" in
        1)
            while true; do
                read -e -p "Enter a port of your choice: " chosen_port
                if [[ "$chosen_port" =~ ^[0-9]+$ ]]; then
                    if [[ " ${reserved_ports[@]} " =~ " $chosen_port " ]]; then
                        echo -e "\e[31mPort $chosen_port is a reserved port. Please choose another port.\e[0m"
                    elif ! is_port_available "$chosen_port"; then
                        echo -e "\e[31mPort $chosen_port is already in use. Please choose another port.\e[0m"
                    else
                        port=$chosen_port
                        echo -e "Using custom port: \e[32m$port\e[0m"
                        break 2
                    fi
                else
                    echo -e "\e[31mInvalid port number. Please enter a valid number.\e[0m"
                fi
            done
            ;;
        2)
            echo -e "\e[32mSearching for available port...\e[0m"
            port=$(generate_random_port)
            if [[ -z "$port" ]]; then
                echo -e "\e[31mNo available port found in range 5001-9000.\e[0m"
                exit 1
            fi
            echo -e "Using random port: \e[32m$port\e[0m"
            break
            ;;
        3)
            echo -e "\e[31mExiting...\e[0m"
            exit 0
            ;;
        *)
            echo -e "\e[31mInvalid option. Please enter 1, 2, or 3.\e[0m"
            ;;
    esac
done

# ************************************************************ start hosting nop ************************************************************

#nop hosting dir
sudo ufw allow $port
check_and_create_directory $nopHostingDir

#install asp.net
# Set .NET version
# Check if the required ASP.NET Core Runtime is already installed
if ! (command -v dotnet &>/dev/null && dotnet --list-runtimes | grep -q "Microsoft.AspNetCore.App $dotnetVersion"); then
    echo -e "\e[93mASP.NET Core Runtime $dotnetVersion is not installed. Installing...\e[0m"
    
    # Identify Ubuntu version
    ubuntu_version=$(lsb_release -rs)
    ubuntu_major=$(echo "$ubuntu_version" | cut -d. -f1)
    
    if [ "$ubuntu_major" -ge 22 ]; then
        # For Ubuntu 22.04+ (Jammy/Noble), use Canonical's official backports to avoid repository conflicts
        echo "Ubuntu 22.04+ detected. Using native repositories / Backports PPA..."
        sudo add-apt-repository ppa:dotnet/backports -y
        sudo apt update -y
    else
        # Fallback for Ubuntu 20.04 (Focal) or older
        echo "Ubuntu version older than 22.04 detected. Using Microsoft repository..."
        wget "https://packages.microsoft.com/config/ubuntu/$ubuntu_version/packages-microsoft-prod.deb" -O packages-microsoft-prod.deb
        sudo dpkg -i packages-microsoft-prod.deb
        rm -f packages-microsoft-prod.deb
        sudo apt update -y
        sudo apt install -y apt-transport-https
    fi
    
    # Install ASP.NET Core Runtime (this automatically installs the base dotnet-runtime as well)
    sudo apt install -y aspnetcore-runtime-$dotnetVersion
    
    echo -e "\e[92mASP.NET Core Runtime $dotnetVersion installed successfully.\e[0m"
else
    echo -e "\e[92mASP.NET Core Runtime $dotnetVersion is already installed.\e[0m"
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

# Resolve the dynamic dotnet binary path
dotnetPath=$(which dotnet 2>/dev/null || echo "/usr/bin/dotnet")

#!/bin/bash
cd "$etcPath"

sudo cat <<EOF > "$serviceName"
[Unit]
Description=NopCommerce $nopVersion application type of $selectedSiteType for $dirNServiceName

[Service]
WorkingDirectory=$nopHostingDir
ExecStart=$dotnetPath "$nopHostingDir/Nop.Web.dll" --urls=http://0.0.0.0:$port
Restart=always

# Auto restart nopCommerce in 10 seconds if .NET crashes

RestartSec=10
KillSignal=SIGINT
SyslogIdentifier=nopcommerce
User=www-data
Environment=ASPNETCORE_ENVIRONMENT=Production
Environment=DOTNET_PRINT_TELEMETRY_MESSAGE=false
Environment=ASPNETCORE_FORWARDEDHEADERS_ENABLED=true
Environment=ASPNETCORE_FORWARDEDHEADERS_FORWARDLIMIT=1
Environment=ASPNETCORE_FORWARDEDHEADERS_KNOWNPROXIES=127.0.0.1


[Install]
WantedBy=multi-user.target
EOF

echo -e "\e[93m$serviceName\e[0m file created successfully."

sudo cat "$serviceName"


sudo systemctl daemon-reload
sudo systemctl enable $serviceName
sudo systemctl start $serviceName

echo -e "\e[31mnopCommerce is hosted on the port : \"$port\". If you are using any cloud service with a public IP, please allow the port: \"$port\" from their dashboard if you want to access with the IP\e[0m"