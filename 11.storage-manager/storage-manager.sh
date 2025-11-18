#!/bin/bash

# Storage Manager Script
# Purpose: Manage Disk operation safely
# Author: samiulAsumel

set -eou pipefail

# Color Codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Loging functions
log() {
	echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
	echo -e "${RED}[ERROR]${NC} $1" >&2
}

warning() {
	echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Check if running as root/wheel
check_root() {
	if [[ $EUID -ne 0 ]]; then
		error "This script must be run as root."
		exit 1
	fi
}

# Display available disks
show_disk() {
	log "Available storage devices:"
	echo "---------------------------------"
	lsblk -o NAME,SIZE,TYPE,MOUNTPOINT,FSTYPE
	echo "---------------------------------"
}

# Create file system with safety checks
create_filesystem() {
	local device=$1
	local fstype=${2:-ext4}
	local label=$3

	# Safety check: Is device mounted?
	if mount | grep -q "^$device " ; then
		error "Device $device is currently nounted!"
		return 1 
	fi

	# Confirmation prompt
	warning "This will erase all data on $device. Are you sure? (yes/no)"
	read -p "Type 'YES' to continue: " confirmation

	if [[ "$confirmation" != "YES" ]]; then
		log "Operation canceled by user."
		return 1
	fi

	# Create file system
	log "Creating $fstype file system on $device..."
	if [[ -n "$label" ]]; then
		mkfs.$fstype -L "$label" "$device"
	else
		mkfs.$fstype "$device"
	fi

	log "File system created successfully"
	blkid "$device"
}

# Mount with validation
safe_mount() {
	local device=$1
	local mountpoint=$2
	local options=${3:-defaults}

	# Check if mountpoint exists
}