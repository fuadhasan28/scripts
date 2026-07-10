#!/bin/bash

# Check if script is run as root or with sudo
if [ "$(id -u)" != "0" ]; then
   echo -e "\e[31mThis script must be run as root or with sudo\e[0m"
   exit 1
fi

# ************************************************************
# Utility Functions
# ************************************************************

check_and_create_directory() {
    local dir="$1"
    if [ ! -d "$dir" ]; then
        echo "Creating directory: $dir"
        sudo mkdir -p "$dir"
    fi
    sudo chmod 755 "$dir"
}

change_permission_and_owner() {
    local dir="$1"
    local owner="$2"
    local group="$3"
    
    echo "Setting permissions for $dir"
    sudo chmod -R 755 "$dir"
    sudo chown -R "$owner":"$group" "$dir"
}

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
reserved_ports=(80 22 443 5432 8069 8072)

# Function to generate a random port
generate_random_port() {
    local available_ports=()
    for ((port=8070; port<=8090; port++)); do
        if [[ ! " ${reserved_ports[@]} " =~ " $port " ]] && is_port_available "$port"; then
            available_ports+=("$port")
        fi
    done
    # Select a random port from available ports
    local random_index=$((RANDOM % ${#available_ports[@]}))
    echo "${available_ports[random_index]}"
}

# Prompt user to accept, deny, choose a port, or exit
prompt_user_for_port() {
    local port="$1"
    while true; do
        echo -e "A random port \e[93m$port\e[0m is available for Odoo. Do you want to accept it? \e[91mType(y/n) or 'exit' to exit or type 'c' \e[0mto input a port of your choice (Any other input to continue with \e[93m$port\e[0m port): " 
        read -p "Your choice: " choice
        case "$choice" in
            n|N) return 1 ;;
            exit) echo -e "\e[32mExiting...\e[0m"; exit ;;
            c) read -p "Enter a port of your choice: " chosen_port
                    if [[ "$chosen_port" =~ ^[0-9]+$ ]]; then
                        if ! [[ " ${reserved_ports[@]} " =~ " $chosen_port " ]] && is_port_available "$chosen_port"; then
                            echo -e "Chosen port \e[93m$chosen_port\e[0m is available."
                            port=$chosen_port
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

# Function to validate input
validate_input() {
    local input="$1"
    if [[ ${#input} -le 2 || $input =~ [^a-zA-Z0-9_.] ]]; then
        return 1
    else
        return 0
    fi
}

# ************************************************************
# Base Configuration
# ************************************************************

# Define base paths
etcPath="/etc/systemd/system"
odooVersion="18.0"
odooUser="odoo"
odooGroup="odoo"
defaultInstallPath="/opt/odoo"

# Environment options
envTypeOptions=(
    "Development"
    "Production"
    "Testing"
    "Staging"
    "Custom"
)

# Initialize with default
selectedEnvType="Production"

# Function to print available environment types
print_env_types() {
    echo -e "Available environment types:\e[33m"
    for i in "${!envTypeOptions[@]}"; do
        echo "$((i+1)) : ${envTypeOptions[i]}"
    done
    echo -e "\e[0mPlease enter a number between 1 and ${#envTypeOptions[@]}, or press Enter to use the default [Production]."
}

# Function to validate env type index
validate_env_type_index() {
    local index="$1"
    if [[ "$index" =~ ^[0-9]+$ && "$index" -ge 1 && "$index" -le ${#envTypeOptions[@]} ]]; then
        return 0
    else
        return 1
    fi
}

# ************************************************************
# Start Installation Process
# ************************************************************

echo -e "\e[34m"
echo "╔═══════════════════════════════════════════════╗"
echo "║         ODOO 18 INSTALLATION SCRIPT           ║"
echo "╚═══════════════════════════════════════════════╝"
echo -e "\e[0m"

# Ask for installation path
read -p "Enter Odoo installation path (default: /opt/odoo): " installPath
installPath=${installPath:-$defaultInstallPath}

# Create installation directory
check_and_create_directory "$installPath"

# ************************************************************
# Environment Selection
# ************************************************************

# Display environment types and get user input
print_env_types

while true; do
    read -p "Enter an index for environment type (default is Production): " envTypeIndex
    if [[ -z "$envTypeIndex" ]]; then
        echo "No input provided. Using default environment type: $selectedEnvType"
        break
    elif validate_env_type_index "$envTypeIndex"; then
        valid_env_type_index=$((envTypeIndex-1))
        selectedEnvType="${envTypeOptions[valid_env_type_index]}"
        
        # If "Custom" is selected, ask for custom input
        if [[ "$selectedEnvType" == "Custom" ]]; then
            read -p "Please enter a custom environment type: " customEnvType
            if [[ -n "$customEnvType" ]]; then
                selectedEnvType="$customEnvType"
                echo "Custom environment type selected: $selectedEnvType"
            else
                echo "No input provided. Defaulting to 'Custom'."
                selectedEnvType="Custom"
            fi
        else
            echo "Selected environment type: ${selectedEnvType}"
        fi
        break
    else
        echo "Invalid value. Please enter a valid number between 1 and ${#envTypeOptions[@]}, or press Enter to use the default."
    fi
done

echo "Proceeding with environment type: $selectedEnvType"

# ************************************************************
# Instance Name Selection
# ************************************************************

# Main loop to take input for instance name
while true; do
    read -p "Enter a name for Odoo instance (length > 2, no special characters or spaces): " instanceName
    if ! validate_input "$instanceName"; then
        echo "Invalid input. Please try again."
    else
        serviceName="odoo-${selectedEnvType,,}-${instanceName}.service"
        
        # Check if service file exists
        if [ -f "$etcPath/$serviceName" ]; then
            echo "Service file '$etcPath/$serviceName' already exists. Please choose another name."
            continue
        fi
        
        # Check if directory exists
        instanceDir="$installPath/${selectedEnvType,,}_${instanceName}"
        if [ -d "$instanceDir" ]; then
            echo "Directory '$instanceDir' already exists. Please choose another name."
            continue
        fi
        
        break
    fi
done

echo -e "Instance name: \e[93m$instanceName\e[0m"
echo -e "Installation directory: \e[93m$instanceDir\e[0m"
echo -e "Service name: \e[93m$serviceName\e[0m"

# ************************************************************
# Port Selection for Odoo
# ************************************************************

# Main script for port selection
echo -e "\e[32mSearching for available port for Odoo...\e[0m"
while true; do
    odooPort=$(generate_random_port)
    if [[ -z "$odooPort" ]]; then
        echo -e "\e[31mNo available port found.\e[0m"
        exit 1
    fi
    if prompt_user_for_port "$odooPort"; then
        echo -e "Odoo will run on port: \e[32m$odooPort\e[0m"
        break
    else
        echo -e "Port \e[31m$odooPort\e[0m denied. Searching for another available port..."
    fi
done

# ************************************************************
# Longpolling Port Selection
# ************************************************************

# Add odooPort to reserved ports temporarily to avoid conflicts
reserved_ports+=($odooPort)

echo -e "\e[32mSearching for available port for Odoo Longpolling...\e[0m"
while true; do
    longpollingPort=$((odooPort + 3))
    if is_port_available "$longpollingPort"; then
        echo -e "Longpolling port \e[32m$longpollingPort\e[0m is available."
        break
    else
        longpollingPort=$((longpollingPort + 1))
    fi
done

echo -e "Odoo Longpolling will run on port: \e[32m$longpollingPort\e[0m"

# ************************************************************
# Database Configuration
# ************************************************************

# Generate random password
dbPassword=$(< /dev/urandom tr -dc A-Za-z0-9 | head -c14)
dbUser="odoo_${instanceName}"
dbName="odoo_${instanceName}"

# ************************************************************
# System Preparation
# ************************************************************

echo -e "\e[34m"
echo "╔═══════════════════════════════════════════════╗"
echo "║         PREPARING SYSTEM FOR ODOO 18          ║"
echo "╚═══════════════════════════════════════════════╝"
echo -e "\e[0m"

# Update package lists
echo "Updating package lists..."
sudo apt update

# Install required dependencies
echo "Installing dependencies..."
sudo apt install -y git python3 python3-pip build-essential wget python3-dev python3-venv \
    python3-wheel libfreetype6-dev libxml2-dev libzip-dev libldap2-dev libsasl2-dev \
    python3-setuptools node-less libjpeg-dev zlib1g-dev libpq-dev \
    libxslt1-dev libldap2-dev libtiff5-dev libjpeg8-dev libopenjp2-7-dev \
    liblcms2-dev libwebp-dev libharfbuzz-dev libfribidi-dev libxcb1-dev

# Check if nc (netcat) is installed, if not install it
if ! command -v nc &> /dev/null; then
    echo "Installing netcat for port checking..."
    sudo apt install -y netcat
fi

# Check if PostgreSQL is installed
if ! command -v psql &> /dev/null; then
    echo "PostgreSQL is not installed. Installing..."
    sudo apt install -y postgresql postgresql-contrib
    # Start and enable PostgreSQL
    sudo systemctl start postgresql
    sudo systemctl enable postgresql
else
    echo "PostgreSQL is already installed."
fi

# ************************************************************
# Create Odoo User
# ************************************************************

# Check if odoo user exists
if ! id -u $odooUser &>/dev/null; then
    echo "Creating odoo system user..."
    sudo adduser --system --home=$installPath --group $odooUser
else
    echo "Odoo user already exists."
fi

# ************************************************************
# Directory Structure Creation
# ************************************************************

echo "Creating Odoo directory structure..."

# Create main directories
check_and_create_directory "$instanceDir"
check_and_create_directory "$instanceDir/addons"
check_and_create_directory "$instanceDir/custom-addons"
check_and_create_directory "$instanceDir/logs"
check_and_create_directory "$instanceDir/backups"
check_and_create_directory "$instanceDir/data"
check_and_create_directory "$instanceDir/etc"

# Change ownership of the directories
change_permission_and_owner "$instanceDir" "$odooUser" "$odooGroup"

# ************************************************************
# PostgreSQL Database Setup
# ************************************************************

echo "Setting up PostgreSQL for Odoo..."

# Create PostgreSQL user for Odoo
sudo -u postgres psql -c "CREATE USER $dbUser WITH PASSWORD '$dbPassword';" || true
sudo -u postgres psql -c "ALTER USER $dbUser WITH SUPERUSER;" || true

# Create PostgreSQL database for Odoo
sudo -u postgres psql -c "CREATE DATABASE $dbName WITH OWNER $dbUser;" || true
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE $dbName TO $dbUser;" || true

# ************************************************************
# Download and Setup Odoo
# ************************************************************

echo "Downloading Odoo 18.0 from GitHub..."

# Clone Odoo repository
cd "$instanceDir"
sudo -u $odooUser git clone --depth 1 --branch $odooVersion https://github.com/odoo/odoo.git "$instanceDir/odoo"

# Setup Python virtual environment
echo "Setting up Python virtual environment..."
sudo -u $odooUser python3 -m venv "$instanceDir/venv"

# Activate virtual environment and install requirements
echo "Installing Python dependencies..."
sudo -u $odooUser bash -c "cd $instanceDir && source venv/bin/activate && pip3 install wheel && pip3 install -r odoo/requirements.txt"

# ************************************************************
# Configure Odoo
# ************************************************************

echo "Configuring Odoo..."

# Create Odoo configuration file
sudo -u $odooUser cat > "$instanceDir/etc/odoo.conf" << EOF
[options]
; General Settings
admin_passwd = admin
db_host = localhost
db_port = 5432
db_user = $dbUser
db_password = $dbPassword
db_name = $dbName
addons_path = $instanceDir/odoo/addons,$instanceDir/custom-addons
data_dir = $instanceDir/data
logfile = $instanceDir/logs/odoo.log

; HTTP Services
http_port = $odooPort
longpolling_port = $longpollingPort

; Security
list_db = True
proxy_mode = True

; Performance
workers = 2
max_cron_threads = 1
limit_time_cpu = 600
limit_time_real = 1200

; Environment
environment = ${selectedEnvType,,}
EOF

# Set permissions
sudo chown $odooUser:$odooGroup "$instanceDir/etc/odoo.conf"
sudo chmod 640 "$instanceDir/etc/odoo.conf"

# ************************************************************
# Create Systemd Service
# ************************************************************

echo "Creating systemd service for Odoo..."

sudo cat > "$etcPath/$serviceName" << EOF
[Unit]
Description=Odoo $odooVersion ($selectedEnvType - $instanceName)
After=network.target postgresql.service
Requires=postgresql.service

[Service]
Type=simple
User=$odooUser
Group=$odooGroup
ExecStart=$instanceDir/venv/bin/python3 $instanceDir/odoo/odoo-bin -c $instanceDir/etc/odoo.conf
Restart=always
RestartSec=10
SyslogIdentifier=odoo-$selectedEnvType-$instanceName
KillMode=mixed

[Install]
WantedBy=multi-user.target
EOF

# Set proper permissions
sudo chmod 644 "$etcPath/$serviceName"

# Reload systemd, enable and start Odoo service
echo "Enabling and starting Odoo service..."
sudo systemctl daemon-reload
sudo systemctl enable $serviceName
sudo systemctl start $serviceName

# Open firewall for Odoo ports if UFW is installed
if command -v ufw &> /dev/null; then
    echo "Opening firewall ports..."
    sudo ufw allow $odooPort/tcp
    sudo ufw allow $longpollingPort/tcp
fi

# ************************************************************
# Final Output
# ************************************************************

echo -e "\e[34m"
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║                  ODOO 18 INSTALLATION COMPLETE                ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo -e "\e[0m"

echo -e "\e[32mOdoo Service:\e[0m \e[93m$serviceName\e[0m"
echo -e "\e[32mOdoo Web Interface:\e[0m \e[93mhttp://localhost:$odooPort\e[0m"
echo -e "\e[32mOdoo Longpolling Port:\e[0m \e[93m$longpollingPort\e[0m"
echo -e "\e[32mDatabase Name:\e[0m \e[93m$dbName\e[0m"
echo -e "\e[32mDatabase User:\e[0m \e[93m$dbUser\e[0m"
echo -e "\e[32mDatabase Password:\e[0m \e[91m$dbPassword\e[0m"
echo -e "\e[32mInstallation Directory:\e[0m \e[93m$instanceDir\e[0m"
echo -e "\e[32mConfig File:\e[0m \e[93m$instanceDir/etc/odoo.conf\e[0m"
echo -e "\e[32mDefault Odoo Admin Password:\e[0m \e[91madmin\e[0m (Change this immediately!)"

echo ""
echo -e "\e[31mIMPORTANT: Odoo is now running on port $odooPort. If you're using a cloud service with a public IP,"
echo -e "please make sure to properly configure your firewall to allow access to this port if needed.\e[0m"
echo ""
echo -e "\e[33mTo access Odoo:\e[0m"
echo -e "1. Open a web browser and navigate to: \e[93mhttp://YOUR_SERVER_IP:$odooPort\e[0m"
echo -e "2. Create a new database or login using the master password: \e[91madmin\e[0m"
echo ""
echo -e "\e[33mUseful commands:\e[0m"
echo -e "- Check service status: \e[96msudo systemctl status $serviceName\e[0m"
echo -e "- Restart Odoo service: \e[96msudo systemctl restart $serviceName\e[0m"
echo -e "- View logs: \e[96msudo tail -f $instanceDir/logs/odoo.log\e[0m"