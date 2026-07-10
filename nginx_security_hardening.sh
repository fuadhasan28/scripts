#!/bin/bash

#############################################################################
# Nginx Security Hardening Script with Backup & Rollback
# Purpose: Apply security hardening and IP logging fixes to Nginx configs
# Features: Backup original files, validate changes, rollback on error
#############################################################################

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Variables
NGINX_CONFIG=""
SERVICE_NAME=""
BACKUP_DIR="/tmp/nginx_hardening_backup_$(date +%s)"
ROLLBACK=false

#############################################################################
# Functions
#############################################################################

# Print colored output
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Cleanup function on script exit
cleanup_on_exit() {
    if [ "$ROLLBACK" = true ]; then
        print_warning "Rolling back changes..."
        restore_backups
        print_info "Rollback completed. Original files restored."
    fi
}

trap cleanup_on_exit EXIT

# Validate input files
validate_files() {
    if [ ! -f "$NGINX_CONFIG" ]; then
        print_error "Nginx config file not found: $NGINX_CONFIG"
        return 1
    fi
    
    if [ ! -f "$SERVICE_FILE" ]; then
        print_error "Service file not found: $SERVICE_FILE"
        return 1
    fi
    
    return 0
}

# Create backups
create_backups() {
    print_info "Creating backups..."
    mkdir -p "$BACKUP_DIR"
    
    cp "$NGINX_CONFIG" "$BACKUP_DIR/nginx_config.bak"
    cp "$SERVICE_FILE" "$BACKUP_DIR/service.bak"
    
    print_success "Backups created in: $BACKUP_DIR"
}

# Restore backups
restore_backups() {
    if [ ! -d "$BACKUP_DIR" ]; then
        print_error "Backup directory not found: $BACKUP_DIR"
        return 1
    fi
    
    sudo cp "$BACKUP_DIR/nginx_config.bak" "$NGINX_CONFIG"
    sudo cp "$BACKUP_DIR/service.bak" "$SERVICE_FILE"
    
    print_success "Backups restored successfully"
}

# Extract domain name from nginx config
get_domain_from_config() {
    grep "server_name" "$NGINX_CONFIG" | head -1 | awk '{print $2}' | sed 's/[;]$//'
}

# Add Cloudflare real IP settings
add_cloudflare_ips() {
    print_info "Adding Cloudflare real IP settings..."
    
    local cloudflare_ips=(
        "173.245.48.0/20"
        "103.21.244.0/22"
        "103.22.200.0/22"
        "103.31.4.0/22"
        "141.101.64.0/18"
        "108.162.192.0/18"
        "190.93.240.0/20"
        "188.114.96.0/20"
        "197.234.240.0/22"
        "198.41.128.0/17"
        "162.158.0.0/15"
        "104.16.0.0/13"
        "104.24.0.0/14"
        "172.64.0.0/13"
        "131.0.252.0/22"
    )
    
    # Add in reverse order to maintain correct sequence at top of file
    for ip in "${cloudflare_ips[@]}"; do
        sudo sed -i "1i set_real_ip_from $ip;" "$NGINX_CONFIG"
    done
    
    sudo sed -i "1i real_ip_header CF-Connecting-IP;" "$NGINX_CONFIG"
    
    print_success "Cloudflare IPs added"
}

# Add host-based validation
add_host_validation() {
    print_info "Adding host-based validation..."
    
    local domain=$(get_domain_from_config)
    
    sudo sed -i "/server_name.*$domain;/a\\    if (\$host != \"$domain\") {\\n        return 444;\\n    }" "$NGINX_CONFIG"
    
    print_success "Host validation added for domain: $domain"
}

# Add X-Real-IP header
add_real_ip_header() {
    print_info "Adding X-Real-IP header to proxy settings..."
    
    sudo sed -i '/proxy_set_header   X-Forwarded-Proto \$scheme;/a\\                proxy_set_header   X-Real-IP \$remote_addr;' "$NGINX_CONFIG"
    
    print_success "X-Real-IP header added"
}

# Add sensitive path blocking
add_path_blocking() {
    print_info "Adding sensitive path blocking..."
    
    local path_blocks='    location ~ /.git {\n        deny all;\n        return 404;\n    }\n\n    location ~ \\.log$ {\n        deny all;\n        return 404;\n    }\n\n    location ~ \\.yml$ {\n        deny all;\n        return 404;\n    }\n\n    location ~ ^/wp-json {\n        deny all;\n        return 404;\n    }\n\n    location ~ ^/wp-content/server-info {\n        deny all;\n        return 404;\n    }\n\n    location ~* \\.php$ {\n        return 404;\n    }'
    
    sudo sed -i "/client_max_body_size 100M;/a\\$path_blocks" "$NGINX_CONFIG"
    
    print_success "Sensitive path blocking added"
}

# Validate nginx configuration
validate_nginx_config() {
    print_info "Validating Nginx configuration..."
    
    if ! sudo nginx -t; then
        print_error "Nginx configuration validation failed!"
        ROLLBACK=true
        return 1
    fi
    
    print_success "Nginx configuration is valid"
    return 0
}

# Modify systemd service file
modify_systemd_service() {
    print_info "Modifying systemd service file for ASP.NET Core forwarded headers..."
    
    local service_marker="Environment=DOTNET_PRINT_TELEMETRY_MESSAGE=false"
    
    # Check if forwarded headers are already present
    if sudo grep -q "ASPNETCORE_FORWARDEDHEADERS_ENABLED" "$SERVICE_FILE"; then
        print_warning "Forwarded headers already present in service file"
        return 0
    fi
    
    sudo sed -i "/$service_marker/a Environment=ASPNETCORE_FORWARDEDHEADERS_ENABLED=true\nEnvironment=ASPNETCORE_FORWARDEDHEADERS_FORWARDLIMIT=1\nEnvironment=ASPNETCORE_FORWARDEDHEADERS_KNOWNPROXIES=127.0.0.1" "$SERVICE_FILE"
    
    print_success "ASP.NET Core forwarded headers added to service"
}

# Reload and restart services
reload_services() {
    print_info "Reloading services..."
    
    sudo systemctl daemon-reload
    sudo systemctl reload nginx
    sudo systemctl restart "$SERVICE_NAME"
    
    print_success "Services reloaded and restarted"
}

# Verify service status
verify_services() {
    print_info "Verifying service status..."
    
    if ! sudo systemctl is-active --quiet nginx; then
        print_error "Nginx service is not running!"
        ROLLBACK=true
        return 1
    fi
    
    if ! sudo systemctl is-active --quiet "$SERVICE_NAME"; then
        print_error "$SERVICE_NAME service is not running!"
        ROLLBACK=true
        return 1
    fi
    
    print_success "All services are running"
    return 0
}

# Display summary
display_summary() {
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}Security Hardening Applied Successfully${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo "Configuration Summary:"
    echo "  Nginx Config:     $NGINX_CONFIG"
    echo "  Service Name:     $SERVICE_NAME"
    echo "  Service File:     $SERVICE_FILE"
    echo "  Backup Location:  $BACKUP_DIR"
    echo ""
    echo "Changes Applied:"
    echo "  ✓ Cloudflare real IP settings"
    echo "  ✓ Host-based validation"
    echo "  ✓ X-Real-IP header for proxy"
    echo "  ✓ Sensitive path blocking (.git, .log, .yml, .php, wp-json, etc.)"
    echo "  ✓ ASP.NET Core forwarded headers (service file)"
    echo "  ✓ Nginx and service reloaded/restarted"
    echo ""
    echo "To view changes:"
    echo "  Nginx:   cat $NGINX_CONFIG"
    echo "  Service: cat $SERVICE_FILE"
    echo ""
    echo "To restore from backup:"
    echo "  sudo cp $BACKUP_DIR/nginx_config.bak $NGINX_CONFIG"
    echo "  sudo cp $BACKUP_DIR/service.bak $SERVICE_FILE"
    echo ""
}

#############################################################################
# Main Script
#############################################################################

main() {
    echo -e "${BLUE}==========================================${NC}"
    echo -e "${BLUE}Nginx Security Hardening Script${NC}"
    echo -e "${BLUE}==========================================${NC}"
    echo ""
    
    # Prompt for nginx config file
    read -p "Enter the Nginx config file path [/etc/nginx/sites-available/example.com]: " NGINX_CONFIG
    NGINX_CONFIG=${NGINX_CONFIG:-/etc/nginx/sites-available/example.com}
    
    # Prompt for service name
    read -p "Enter the systemd service name [nop_Demo_VendoeShop_490.service]: " SERVICE_NAME
    SERVICE_NAME=${SERVICE_NAME:-nop_Demo_VendoeShop_490.service}
    
    # Construct service file path
    SERVICE_FILE="/etc/systemd/system/$SERVICE_NAME"
    
    echo ""
    print_info "Configuration Summary:"
    echo "  Nginx Config:   $NGINX_CONFIG"
    echo "  Service Name:   $SERVICE_NAME"
    echo "  Service File:   $SERVICE_FILE"
    echo ""
    
    # Validate input
    print_info "Validating files..."
    if ! validate_files; then
        exit 1
    fi
    
    # Ask for confirmation
    read -p "Do you want to proceed with modifications? (yes/no): " confirm
    if [ "$confirm" != "yes" ]; then
        print_info "Script cancelled."
        exit 0
    fi
    
    echo ""
    print_info "Starting modifications..."
    echo ""
    
    # Create backups
    create_backups
    echo ""
    
    # Apply modifications
    add_cloudflare_ips
    add_host_validation
    add_real_ip_header
    add_path_blocking
    echo ""
    
    # Validate nginx configuration
    if ! validate_nginx_config; then
        exit 1
    fi
    echo ""
    
    # Modify systemd service
    modify_systemd_service
    echo ""
    
    # Reload and restart services
    reload_services
    echo ""
    
    # Verify services
    if ! verify_services; then
        exit 1
    fi
    echo ""
    
    # Display summary
    display_summary
}

# Run main function
main
