#!/bin/bash

##################################################
# TechCorp User Management Automation Script
# Purpose: Streamline user and group operations
# Author: samiulAsumel
##################################################

# Color Format
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
# By default write logs to /var/log (requires sudo) — the logger will use sudo tee when needed.
LOG_FILE="/var/log/user_management.log"
BACKUP_DIR="/backups/users"

# Functions
log_message() {
	local msg
	msg="$(date '+%Y-%m-%d %H:%M:%S') - $1"

	# If LOG_FILE is under /var and not writable by the user, use sudo tee
	if [[ "$LOG_FILE" == /var/* ]] && [[ ! -w "$(dirname "$LOG_FILE")" ]]; then
		echo "$msg" | sudo tee -a "$LOG_FILE" >/dev/null
	else
		echo "$msg" | tee -a "$LOG_FILE" >/dev/null
	fi
}

create_user() {
	local username=$1
	local fullname=$2
	local department=$3

	if id "$username" &>/dev/null; then
		echo -e "${RED}Error: User '$username' already exists.${NC}"
		return 1
	fi

	sudo useradd -m -s /bin/bash -c "$fullname" -G "$department" "$username"

	# Generate random password (try openssl, fallback to /dev/urandom)
	local password
	if command -v openssl >/dev/null 2>&1; then
		password=$(openssl rand -base64 15)
	else
		# base64 of random bytes, trim to 16 chars
		password=$(head -c 48 /dev/urandom | base64 | tr -d '\n' | head -c 16)
	fi

	# Use chpasswd which is more portable than passwd --stdin
	echo "${username}:${password}" | sudo chpasswd
	sudo passwd -e "$username"

	log_message "Created user: $username in department: $department"
	echo -e "${GREEN}User created: $username${NC}"
	echo -e "${YELLOW}Temporary password: $password${NC}"
}

delete_user() {
	local username=$1
	if ! id "$username" &>/dev/null; then
		echo -e "${RED}Error: User $username does not exist.${NC}"
		return 1
	fi

	# Backup home directory if it exists
	sudo mkdir -p "$BACKUP_DIR"
	if [[ -d "/home/$username" ]]; then
		sudo tar -czf "$BACKUP_DIR/${username}-$(date +%Y%m%d_%H%M%S).tar.gz" "/home/$username"
	else
		log_message "No home directory to backup for $username"
	fi

	# Lock and delete
	sudo usermod -L "$username" || true
	sudo pkill -u "$username" 2>/dev/null || true
	sudo userdel -r "$username"

	log_message "Deleted user: $username"
	echo -e "${GREEN}User deleted and backed up (if present): $username${NC}"
}

list_users() {
	echo -e "${GREEN}=== Techcorp Users (UID >= 1000) ===${NC}"
	awk -F: '$3 >= 1000 && $3 < 65534 {print $1, "UID:", $3, "Home:", $6}' /etc/passwd
}

modify_user() {
	local username=$1
	local action=$2
	local value=$3

	case $action in
		addgroup)
			sudo usermod -aG "$value" "$username"
			echo -e "${GREEN}Added $username to group: $value${NC}"
			;;
		changecomment)
			sudo usermod -c "$value" "$username"
			echo -e "${GREEN}Changed comment for $username to: $value${NC}"
			;;
		lock)
			sudo usermod -L "$username"
			echo -e "${GREEN}Locked user: $username${NC}"
			;;
		unlock)
			sudo usermod -U "$username"
			echo -e "${GREEN}Unlocked user: $username${NC}"
			;;
		*)
			echo -e "${YELLOW}Unknown action: $action. Valid: addgroup, changecomment, lock, unlock${NC}"
			return 1
			;;
	esac

	log_message "Modified user: $username - Action: $action"
}

# Menu
show_menu() {
	echo -e "${GREEN}===============================${NC}"
	echo -e "${GREEN}TechCorp User Management Script${NC}"
	echo -e "${GREEN}===============================${NC}"
	echo "1) Create User"
	echo "2) Delete User"
	echo "3) List All User"
	echo "4) Modify User"
	echo "5) View User Details"
	echo "6) Exit"
	echo -n "Enter your choice: "
}

# Main
while true; do
	show_menu
	read -r choice

	case $choice in
		1)
			read -p "Enter username: " username
			read -p "Enter full name: " fullname
			read -p "Enter department: " department
			create_user "$username" "$fullname" "$department"
			;;
		2)
			read -p "Username to delete: " username
			read -p "Confirm deletion (y/n): " confirm

			if [[ $confirm == "y" ]]; then
				delete_user "$username"
			fi
			;;
		3)
			list_users
			;;
		4)
			read -p "Username: " username
			echo "Actions: addgroup, changecomment, lock, unlock"
			read -p "Action: " action
			read -p "Value: " value
			modify_user "$username" "$action" "$value"
			;;
		5)
			read -p "Username: " username
			id "$username"
			groups "$username"
			;;
		6)
			echo "Goodbye!"
			exit 0
			;;
		*)
			echo "Invalid choice. Please try again."
			;;
	esac
done 