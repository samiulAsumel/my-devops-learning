#!/bin/bash

################################################
# Configuration editor toolkit
# Author: samiulAsumel 
################################################

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
BACKUP_DIR="$HOME/projects/config-toolkit/backup"
LOG_FILE="$HOME/projects/config-toolkit/logs/editor.log"
CONFIG_LIST="$HOME/projects/config-toolkit/config/watched-configs.txt"


# Ensure directories exist
mkdir -p "$BACKUP_DIR" "$(dirname "$LOG_FILE")"

################################################
# Function: Log messages
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Function:  Print colored messages
print_info() { echo -e "${BLUE}[INFO] $1${NC}"; }
print_success() { echo -e "${GREEN}[SUCCESS] $1${NC}"; }
print_warning() { echo -e "${YELLOW}[WARNING] $1${NC}"; }
print_error() { echo -e "${RED}[ERROR] $1${NC}"; }

#Function: Create backup
create_backup() {
	local file=$1
	local timestamp=$(date +%Y%m%d_%H%M%S)
	local backup_name="$(basename "$file").backup.$timestamp"
	local backup_path="$BACKUP_DIR/$backup_name"

	if [[ -f "$file" ]]; then
		cp "$file" "$backup_path"
		print_success "Backup created: $backup_path"
		log_message "Backup created for $file"
		echo "#backup_path"
	else
		print_error "File not found: $file"
		return 1
	fi
}

# Function: List watched configuration files
list_configs() {
	print_info "Watched Configuration Files:"
	echo "......................................."

	if [[ -f $CONFIG_LIST ]]; then
		cat -n "$CONFIG_LIST"
	else
		print_warning "No configuration file list found."
		print_info "Created $CONFIG_LIST and add file paths (one per line)."
	fi
	echo "......................................."
}

# Function: View file safely
view_file() {
	local file=$1

	if [[ ! -f "$file" ]]; then
		print_error "File not found: $file"
		return 1
	fi

	 echo ""
	 print_info "Viewing file: $file"
	 echo "......................................."
	 cat -n "$file"
	 echo "......................................."
	 echo ""
}

# Function: Edit file with backup
edit_file () {
	local file=$1
	local editor="${EDITOR:-vim}"

	if [[ ! -f "$file" ]]; then
		print_error "File not found: $file"
		return 1
	fi

	# Create backup first
	local backup_path=$(create_backup "$file")

	if [[ $? -eq 0 ]]; then
		print_info "Opening editor: $editor"
		log_message "Editing file: $file with $editor"

		# Open the editor
		"$editor" "$file"

		# Check if the file was modified
		if ! diff -p "$file" "$backup_path" > /dev/null 2>&1; then
			print_success "File modified successfully"
			log_message "File modified: $file"
		else
			print _info "No changes made to file"
			log_message "File opened but not modified: $file"
		fi
	fi
}

# Function: Compare current file with backup
compare_with_backup() {
	local file=$1

	if [[ ! -f "$file" ]]; then
		print_error "File not found: $file"
		return 1
	fi

	# Find latest backup
	local basename=$(basename "$file")
	local latest_backup=$(ls -t "$BACKUP_DIR/${basename}.backup"* 2>/dev/null | head -1)

	if [[ -z "$latest_backup" ]]; then
		print_warning "No backup found for $file"
		return 1
	fi

	print_info "Comparing with latest backup: $latest_backup"
	diff -u "$latest_backup" "$file" | less

}

# Function: Restore from backup
restore_backup() {
	local file=$1

	if [[ ! -f "$file" ]]; then
		print_error "File not found: $file"
		return 1
	fi

	local basename_file
	basename_file=$(basename "$file")

	# Get all backups for this file
	readarray -t backups < <(ls -t "$BACKUP_DIR/${basename_file}.backup"* 2>/dev/null)

	if [[ ${#backups[@]} -eq 0 ]]; then
		print_error "No backup found for $file"
		return 1
	fi

	print_info "Available backups:"
	for i in "${!backups[@]}"; do
		echo " $((i+1)). $(basename "${backups[$i]}")"
	done

	read -p "Select backup number to restore (or 0 to cancle): " choice

	if [[ "$choice" -gt 0 && "$choice" -le "${#backups[@]}" ]]; then
		local selected_backup="${backups[$((choice-1))]}"

		# Create safety backup of current file
		create_backup "$file" > /dev/null

		# Restore
		cp "$selected_backup" "$file"
		print_success "File restored from: $(basename "$selected_backup")"
		log_message "Restored $file from backup"
	else
		print_info "Restore cancelled"
	fi
}

# Function: Validate configuration syntex
validate_config() {
	local file=$1

	if [[ ! -f "$file" ]]; then
		print_error "File not found: $file"
		return 1
	fi

	case "$file" in
		*.conf)
			# Basic validation for common config files
			if grep -q "^[^#]*[{}]" "$file"; then
				print_info "Appears to be a structured config (Apache/Nginx style)"
			fi
			 print_success "Basic syntax check passed"
            ;;
        *.yaml|*.yml)
            # YAML validation (requires yamllint)
            if command -v yamllint &> /dev/null; then
                yamllint "$file"
            else
                print_warning "yamllint not installed. Install with: sudo yum install yamllint"
            fi
            ;;
        *.json)
            # JSON validation
            if command -v jq &> /dev/null; then
                jq empty "$file" && print_success "Valid JSON"
            else
                python -m json.tool "$file" > /dev/null && print_success "Valid JSON"
            fi
            ;;
        *)
            print_warning "Unknown file type. Manual validation required."
            ;;
    esac
}

# Function: Show menu
show_menu() {
	echo ""
	echo "==============================="
	echo "TechCorp Config Editor Toolkit"
	echo "==============================="
	echo "1. List watched configuration files"
	echo "2. View a config file"
	echo "3. Edit a config file (with backup)"
	echo "4. Compare with backup"
	echo "5. Restore from backup"
	echo "6. Validate config syntax"
	echo "7. View backup directory"
	echo "8. View logs"
	echo "0. Exit"
	echo "==============================="
}

# Main Program
main() {
	print_success "TechCorp Config Editor Toolkit"
	log_message "TechCorp Config Editor Toolkit started"

	while true; do
		show_menu
		read -p "Enter choice: " choice

		case $choice in
			1) list_configs;;
			2)
				read -p "Enter config file path: " config_file
				view_file "$config_file"
				;;
			3)
				read -p "Enter config file path: " config_file
				edit_file "$config_file"
				;;
			4)
				read -p "Enter config file path: " config_file
				compare_with_backup "$config_file"
				;;
			5)
				read -p "Enter config file path: " config_file
				restore_backup "$config_file"
				;;
			6)
				read -p "Enter config file path: " config_file
				validate_config "$config_file"
				;;
			7)
				ls -lh "$BACKUP_DIR"
				;;
			8)
				if [ -f "$LOG_FILE" ]; then
					tail -n 20 "$LOG_FILE"
				else
					print_warning "No log file found"
				fi
				;;
			0) print_info "Exiting..."; exit 0;;
			*) print_error "Invalid choice. Please try again.";;
		esac

		echo ""
		read -p "Press Enter to continue..."
		clear
	done
}

main