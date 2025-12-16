#!/bin/bash

###############################################
# DNS record Manager Script
# Description: Manage DNS records on the DNS server.
# Author: samiulAsumel
###############################################

set -euo pipefail

# Color codes for output formatting
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

ZONE_FILE="/var/named/techcorp.com.db"
REV_ZONE_FILE="/var/named/192.168.1.db"
DOMAIN="techcorp.com"
BACKUP_DIR="/var/named/backups"

# ==========================================
# Function: Backup zone files
# ==========================================
backup_zone_files() {
	mkdir -p "$BACKUP_DIR"
	timestamp=$(date '+%Y%m%d_%H%M%S')
	cp "$ZONE_FILE" "$BACKUP_DIR/techcorp.com.db.bak_$timestamp"
	cp "$REV_ZONE_FILE" "$BACKUP_DIR/192.168.1.db.bak_$timestamp"
	echo -e "${GREEN}✓ Zone files backed up successfully.${NC}"
}

#==============================================================================
# Function: Increment SOA serial
#==============================================================================
increment_serial() {
    local file="$1"
    
    # Get current serial
    current_serial=$(grep -oP '(?<=\s)\d{10}(?=\s*;\s*Serial)' "$file")
    
    if [[ -z "$current_serial" ]]; then
        echo -e "${RED}✗ Could not find serial number${NC}"
        return 1
    fi
    
    # Increment serial
    new_serial=$((current_serial + 1))
    
    # Replace in file
    sed -i "s/$current_serial/$new_serial/g" "$file"
    
    echo -e "${GREEN}✓ Serial updated: $current_serial -> $new_serial${NC}"
}

#==============================================================================
# Function: Add A record
#==============================================================================
add_a_record() {
    local hostname="$1"
    local ip="$2"
    
    echo "Adding A record: $hostname -> $ip"
    
    # Backup first
    backup_zones
    
    # Add to forward zone
    echo "$hostname    IN  A       $ip" >> "$ZONE_FILE"
    
    # Add to reverse zone
    last_octet=$(echo "$ip" | cut -d'.' -f4)
    echo "$last_octet    IN  PTR     $hostname.$DOMAIN." >> "$REV_ZONE_FILE"
    
    # Increment serials
    increment_serial "$ZONE_FILE"
    increment_serial "$REV_ZONE_FILE"
    
    # Validate
    if named-checkzone "$DOMAIN" "$ZONE_FILE" &>/dev/null; then
        echo -e "${GREEN}✓ Zone file valid${NC}"
        
        # Reload zone
        rndc reload "$DOMAIN"
        rndc reload 56.168.192.in-addr.arpa
        
        echo -e "${GREEN}✓ DNS record added successfully${NC}"
    else
        echo -e "${RED}✗ Zone file validation failed${NC}"
        echo "Restoring from backup..."
        # Restore would go here
    fi
}

#==============================================================================
# Function: Display menu
#==============================================================================
show_menu() {
    echo "=============================================="
    echo "  TechCorp DNS Record Manager"
    echo "=============================================="
    echo "1. Add A Record"
    echo "2. Add CNAME Record"
    echo "3. List All Records"
    echo "4. Remove Record"
    echo "5. Reload Zones"
    echo "6. Exit"
    echo "=============================================="
    read -p "Select option [1-6]: " choice
    
    case $choice in
        1)
            read -p "Enter hostname (e.g., test-server): " hostname
            read -p "Enter IP address: " ip
            add_a_record "$hostname" "$ip"
            ;;
        2)
            echo "CNAME record management (to be implemented)"
            ;;
        3)
            echo "Current A Records:"
            grep "IN  A" "$ZONE_FILE"
            ;;
        4)
            echo "Remove record (to be implemented)"
            ;;
        5)
            rndc reload
            echo -e "${GREEN}✓ Zones reloaded${NC}"
            ;;
        6)
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid option${NC}"
            ;;
    esac
}

# Main loop
while true; do
    show_menu
    echo ""
    read -p "Press Enter to continue..."
    clear
done