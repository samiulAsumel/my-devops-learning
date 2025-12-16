#!/bin/bash
#==============================================================================
# Automated DNS Zone Update Script
# Usage: ./update-dns-zone.sh add hostname ip
#        ./update-dns-zone.sh remove hostname
#==============================================================================

ZONE_FILE="/var/named/techcorp.local.zone"
REV_ZONE="/var/named/192.168.56.rev"
BACKUP_DIR="/var/named/backups"
DOMAIN="techcorp.local"

# Create backup
backup_zone() {
    mkdir -p "$BACKUP_DIR"
    timestamp=$(date +%Y%m%d_%H%M%S)
    cp "$ZONE_FILE" "$BACKUP_DIR/zone.backup.$timestamp"
    cp "$REV_ZONE" "$BACKUP_DIR/rev.backup.$timestamp"
}

# Increment serial
increment_serial() {
    local file=$1
    
    current=$(grep -oP '\d{10}(?=\s*;\s*Serial)' "$file")
    new=$((current + 1))
    
    sed -i "s/$current/$new/g" "$file"
    echo "Serial updated: $current -> $new"
}

# Add DNS record
add_record() {
    local hostname=$1
    local ip=$2
    
    echo "Adding: $hostname -> $ip"
    
    # Backup first
    backup_zone
    
    # Check if record exists
    if grep -q "^$hostname\s" "$ZONE_FILE"; then
        echo "Error: Record already exists"
        return 1
    fi
    
    # Add A record
    echo "$hostname    IN  A       $ip" >> "$ZONE_FILE"
    
    # Add PTR record
    last_octet=$(echo "$ip" | cut -d'.' -f4)
    echo "$last_octet    IN  PTR     $hostname.$DOMAIN." >> "$REV_ZONE"
    
    # Update serials
    increment_serial "$ZONE_FILE"
    increment_serial "$REV_ZONE"
    
    # Validate
    if named-checkzone "$DOMAIN" "$ZONE_FILE" &>/dev/null && \
       named-checkzone 56.168.192.in-addr.arpa "$REV_ZONE" &>/dev/null; then
        
        # Reload zones
        rndc reload "$DOMAIN"
        rndc reload 56.168.192.in-addr.arpa
        
        echo "✓ DNS record added successfully"
        
        # Test
        sleep 2
        dig @localhost "$hostname".$DOMAIN +short
        
        return 0
    else
        echo "✗ Zone validation failed!"
        return 1
    fi
}

# Remove DNS record
remove_record() {
    local hostname=$1
    
    echo "Removing: $hostname"
    
    # Backup first
    backup_zone
    
    # Get IP before removing
    ip=$(grep "^$hostname\s" "$ZONE_FILE" | awk '{print $4}')
    
    if [[ -z "$ip" ]]; then
        echo "Error: Record not found"
        return 1
    fi
    
    # Remove A record
    sed -i "/^$hostname\s/d" "$ZONE_FILE"
    
    # Remove PTR record
    last_octet=$(echo "$ip" | cut -d'.' -f4)
    sed -i "/^$last_octet\s.*$hostname/d" "$REV_ZONE"
    
    # Update serials
    increment_serial "$ZONE_FILE"
    increment_serial "$REV_ZONE"
    
    # Validate and reload
    if named-checkzone "$DOMAIN" "$ZONE_FILE" &>/dev/null; then
        rndc reload "$DOMAIN"
        rndc reload 56.168.192.in-addr.arpa
        echo "✓ DNS record removed successfully"
        return 0
    else
        echo "✗ Zone validation failed!"
        return 1
    fi
}

# Main
case "$1" in
    add)
        if [[ -z "$2" ]] || [[ -z "$3" ]]; then
            echo "Usage: $0 add <hostname> <ip>"
            exit 1
        fi
        add_record "$2" "$3"
        ;;
    remove)
        if [[ -z "$2" ]]; then
            echo "Usage: $0 remove <hostname>"
            exit 1
        fi
        remove_record "$2"
        ;;
    *)
        echo "Usage: $0 {add|remove} ..."
        exit 1
        ;;
esac