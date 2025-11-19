#!/bin/bash

# Storage Manager Script
# Purpose: Manage disk operations safely
# Author: samiulAsumel

set -eou pipefail

# Color Codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging functions
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
show_disks() {
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
	if mount | grep -q "^$device "; then
		error "Device $device is currently mounted!"
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
		mkfs."$fstype" -L "$label" "$device"
	else
		mkfs."$fstype" "$device"
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
	if [[ ! -d "$mountpoint" ]]; then
		log "Creating mount point $mountpoint..."
		mkdir -p "$mountpoint"
	fi

	# Check if already mounted
	if mount | grep -q "$mountpoint"; then
		warning "Mount point already in use."
		mount | grep "$mountpoint"
		return 1
	fi

	# Mount
	log "Mounting $device to $mountpoint..."
	mount -o "$options" "$device" "$mountpoint"

	# Verify
	if df -h | grep -q "$mountpoint"; then
		log "Mount successful"
		df -h "$mountpoint"
		return 0
	else
		error "Mount failed"
		return 1
	fi
}

# Add to fstab with backup
add_to_fstab() {
	local device=$1
	local mountpoint=$2
	local fstype=$3
	local options=${4:-defaults}

	# Get UUID
	local uuid
	uuid=$(blkid -s UUID -o value "$device")
	if [[ -z "$uuid" ]]; then
		error "Cannot get UUID for $device"
		return 1
	fi

	# Backup fstab
	local backup="/etc/fstab.backup.$(date +%Y%m%d_%H%M%S)"
	log "Backing up fstab to $backup"
	cp /etc/fstab "$backup"

	# Check if entry already exists
	if grep -q "$uuid" /etc/fstab; then
		warning "UUID already exists in fstab"
		return 1
	fi

	# Add entry
	log "Adding entry to /etc/fstab"
	echo "UUID=$uuid $mountpoint $fstype $options 0 2" >> /etc/fstab

	# Validate
	log "Validating fstab..."
	if mount -a; then
		log "fstab validation successful"
		grep "$uuid" /etc/fstab
		return 0
	else
		error "fstab validation failed! Restoring backup..."
		cp "$backup" /etc/fstab
		return 1
	fi
}

# Check and repair filesystem
check_filesystem() {
	local device=$1

	# Check if mounted
	if mount | grep -q "^$device "; then
		error "Cannot check mounted file system: $device"
		error "Please unmount first: umount $device"
		return 1
	fi

	log "Checking file system on $device..."
	fsck -n "$device"

	local result=$?
	case $result in
		0) log "File system is clean" ;;
		1) warning "Errors found but corrected" ;;
		2) warning "System should be rebooted" ;;
		4) error "Errors left uncorrected" ;;
		*) error "File system check failed" ;;
	esac

	return $result
}

# Repair file system
repair_filesystem() {
	local device=$1

	# Safety check
	if mount | grep -q "^$device "; then
		error "Cannot repair mounted file system: $device"
		return 1
	fi

	warning "This will attempt to repair $device"
	read -p "Type 'YES' to confirm: " confirm

	if [[ "$confirm" != "YES" ]]; then
		log "Operation canceled by user."
		return 1
	fi

	log "Repairing file system on $device..."
	fsck -y "$device"

	log "Repair completed. Exit code: $?"
}

# Show disk usage report
disk_report() {
	log "TechCorp Disk Usage Report"
	echo "==================================="

	echo -e "\nDisk Space Usage:"
	df -h --output=source,size,used,avail,pcent,target | grep -v tmpfs

	echo -e "\nTop 10 Largest Directories:"
	du -h / --max-depth=2 2>/dev/null | sort -hr | head -n 10

	echo -e "\nMount Points:"
	mount | grep "^/dev" | column -t

	echo "==================================="
}

# Main menu
show_menu() {
	echo "==============================="
	echo "TechCorp Storage Management Toolkit"
	echo "==============================="
	echo "1) Show Available Disks"
	echo "2) Create File System"
	echo "3) Mount Device Safely"
	echo "4) Unmount Device"
	echo "5) Add to fstab"
	echo "6) Check File System"
	echo "7) Repair File System"
	echo "8) Disk Usage Report"
	echo "9) Exit"
	echo "==============================="
}

# Main Program
main() {
	check_root

	while true; do
		show_menu
		read -p "Select an option [1-9]: " choice

		case $choice in
			1) show_disks ;;
			2)
				read -p "Device (e.g., /dev/sdb1): " device
				read -p "File System Type (default: ext4): " fstype
				read -p "Label (optional): " label
				create_filesystem "$device" "$fstype" "$label"
				;;
			3)
				read -p "Device (e.g., /dev/sdb1): " device
				read -p "Mount Point (e.g., /mnt/data): " mountpoint
				safe_mount "$device" "$mountpoint"
				;;
			4)
				read -p "Mount Point to unmount (e.g., /mnt/data): " mountpoint
				umount "$mountpoint" && log "Unmounted $mountpoint successfully"
				;;
			5)
				read -p "Device (e.g., /dev/sdb1): " device
				read -p "Mount Point (e.g., /mnt/data): " mountpoint
				read -p "File System Type (e.g., ext4): " fstype
				add_to_fstab "$device" "$mountpoint" "$fstype"
				;;
			6)
				read -p "Device to check (e.g., /dev/sdb1): " device
				check_filesystem "$device"
				;;
			7)
				read -p "Device to repair (e.g., /dev/sdb1): " device
				repair_filesystem "$device"
				;;
			8) disk_report ;;
			9) log "Exiting Storage Manager. Goodbye!"; exit 0 ;;
			*) warning "Invalid option. Please select between 1-9." ;;
		esac

		echo ""
		read -p "Press Enter to continue..."
		clear
	done
}

main